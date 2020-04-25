#  logic initially based on pp_simple.pl
#  Should cache the Module::Scandeps result
#  and then clean it up after using it.

use 5.020;
use warnings;
use strict;

our $VERSION = '2.00';

use Carp;
use English qw / -no_match_vars /;

use File::Which      qw( which );
use Capture::Tiny    qw/ capture /;
use List::Util       qw( uniq any );
use File::Find::Rule qw/ rule find /;
use Path::Tiny       qw/ path /;
use File::Temp       qw/ tempfile /;
use Module::ScanDeps;
use Env qw /@PATH/;

use Config;

my $RE_DLL_EXT = qr/\.$Config::Config{so}$/i;
my $get_autolink_list_sub = \&get_autolink_list;

if ($^O eq 'darwin') {
    $RE_DLL_EXT = qr/\.($Config::Config{so}|bundle)$/i;
    $get_autolink_list_sub = \&get_autolink_list_macos; 
}

my $ldd_exe = which('ldd');
if ($ldd_exe) {
    $get_autolink_list_sub = \&get_autolink_list_ldd;
}

use constant CASE_INSENSITIVE_OS => ($^O eq 'MSWin32');

#  messy arg handling - ideally would use a GetOpts variant that allows
#  pass through to pp without needing to set them after --
#  Should also trap any scandeps args (if diff from pp).
#  pp also allows multiple .pl files.
my $script_fullname = $ARGV[-1] or die 'no input file specified';
#  does not handle -x as a value for some other arg like --somearg -x
my $no_execute_flag = not grep {$_ eq '-x'} @ARGV;

#  should use a getopt module for this 
my @argv_linkers;
foreach my $idx (0 .. $#ARGV) {
    next if $ARGV[$idx] ne '--link';
    push @argv_linkers, $ARGV[$idx+1];
}

#  Try caching - scandeps will execute for us, and then we use a cache file
#  Nope, did not get it to work, so disable for now
#my @args_for_pp = grep {$_ ne '-x'} @ARGV;
my @args_for_pp = @ARGV;

my ($cache_fh, $cache_file);
#($cache_fh, $cache_file)
#  = tempfile( 'pp_autolink_cache_file_XXXXXX',
#               TMPDIR => 1
#            );

die "Script $script_fullname does not have a .pl extension"
  if !$script_fullname =~ /\.pl$/;

my @links = map {('--link' => $_)}
            $get_autolink_list_sub->($script_fullname, $no_execute_flag);

say 'Detected link list: ' . join ' ', @links;

my @command = (
    'pp',
    @links,
    #"--cachedeps=$cache_file",
    @args_for_pp,
);

#say join ' ', @command;
system @command;

#undef $cache_fh;
#unlink $cache_file;

sub get_autolink_list {
    my ($script, $no_execute_flag) = @_;

    my $OBJDUMP   = which('objdump')  or die "objdump not found";
    
    my @exe_path = @PATH;
    
    my @system_paths;

    if ($OSNAME =~ /MSWin32/i) {
        #  skip anything under the C:\Windows folder
        #  and no longer existant folders 
        my $system_root = $ENV{SystemRoot};
        @system_paths = grep {$_ =~ m|^\Q$system_root\E|i} @exe_path;
        @exe_path = grep {(-e $_) and $_ !~ m|^\Q$system_root\E|i} @exe_path;
        #say "PATHS: " . join ' ', @exe_path;
    }
    #  what to skip for linux or mac?
    
    #  get all the DLLs in the path - saves repeated searching lower down
    my @dll_files = File::Find::Rule->file()
                            ->name( "*.$Config::Config{so}" )
                            ->maxdepth(1)
                            ->in( @exe_path );

    if (CASE_INSENSITIVE_OS) {
        @dll_files = map {lc $_} @dll_files;
    }

    my %dll_file_hash;
    foreach my $file (@dll_files) {
        my $basename = path($file)->basename;
        $dll_file_hash{$basename} //= $file;  #  we only want the first in the path
    }


    #  lc is dirty and underhanded
    #  - need to find a different approach to get
    #  canonical file name while handling case,
    #  poss Win32::GetLongPathName
    my @dlls = @argv_linkers;
    push @dlls,
      get_dep_dlls ($script, $no_execute_flag);

    if (CASE_INSENSITIVE_OS) {
        @dlls = map {lc $_} @dlls;
    }
    #say join "\n", @dlls;
    
    my $re_skippers = get_dll_skipper_regexp();
    my %full_list;
    my %searched_for;
    my $iter = 0;
    
    my @missing;

  DLL_CHECK:
    while (1) {
        $iter++;
        say "DLL check iter: $iter";
        #say join ' ', @dlls;
        my ( $stdout, $stderr, $exit ) = capture {
            system( $OBJDUMP, '-p', @dlls );
        };
        if( $exit ) {
            $stderr =~ s{\s+$}{};
            warn "(@dlls):$exit: $stderr ";
            exit;
        }
        @dlls = $stdout =~ /DLL.Name:\s*(\S+)/gmi;
        
        if (CASE_INSENSITIVE_OS) {
            @dlls = map {lc $_} @dlls;
        }

        #  extra grep appears wasteful but useful for debug 
        #  since we can easily disable it
        @dlls
          = sort
            grep {!exists $full_list{$_}}
            grep {$_ !~ /$re_skippers/}
            uniq
            @dlls;
        
        if (!@dlls) {
            say 'no more DLLs';
            last DLL_CHECK;
        }
                
        my @dll2;
        foreach my $file (@dlls) {
            next if $searched_for{$file};
        
            if (exists $dll_file_hash{$file}) {
                push @dll2, $dll_file_hash{$file};
            }
            else {
                push @missing, $file;
            }
    
            $searched_for{$file}++;
        }
        @dlls = uniq @dll2;
        my $key_count = keys %full_list;
        @full_list{@dlls} = (1) x @dlls;
        
        #  did we add anything new?
        last DLL_CHECK if $key_count == scalar keys %full_list;
    }
    
    my @l2 = sort keys %full_list;
    
    if (@missing) {
        my @missing2;
      MISSING:
        foreach my $file (uniq @missing) {
            next MISSING
              if any {-e "$_/$file"} @system_paths;
            push @missing2, $file;
        }
        
        say STDERR "\nUnable to locate these DLLS, packed script might not work: "
        . join  ' ', sort {$a cmp $b} @missing2;
        say '';
    }

    return wantarray ? @l2 : \@l2;
}

sub get_autolink_list_macos {
    my ($script, $no_execute_flag) = @_;

    my $OTOOL = which('otool')  or die "otool not found";
    
    my @bundle_list = get_dep_dlls ($script, $no_execute_flag);
    my @libs_to_pack;
    my %seen;

    my @target_libs = (
        @argv_linkers,
        @bundle_list,
        #'/usr/local/opt/libffi/lib/libffi.6.dylib',
        #($pixbuf_query_loader,
        #find_so_files ($gdk_pixbuf_dir) ) if $pack_gdkpixbuf,
    );
    while (my $lib = shift @target_libs) {
        say "otool -L $lib";
        my @lib_arr = qx /otool -L $lib/;
        warn qq["otool -L $lib" failed\n]
          if not $? == 0;
        shift @lib_arr;  #  first result is dylib we called otool on
        foreach my $line (@lib_arr) {
            $line =~ /^\s+(.+?)\s/;
            my $dylib = $1;
            next if $seen{$dylib};
            next if $dylib =~ m{^/System};  #  skip system libs
            #next if $dylib =~ m{^/usr/lib/system};
            next if $dylib =~ m{^/usr/lib/libSystem};
            next if $dylib =~ m{^/usr/lib/};
            next if $dylib =~ m{\Qdarwin-thread-multi-2level/auto/share/dist/Alien\E};  #  another alien
            say "adding $dylib for $lib";
            push @libs_to_pack, $dylib;
            $seen{$dylib}++;
            #  add this dylib to the search set
            push @target_libs, $dylib;
        }
    }

    @libs_to_pack = sort @libs_to_pack;
    
    return wantarray ? @libs_to_pack : \@libs_to_pack;
}

sub get_autolink_list_ldd {
    my ($script, $no_execute_flag) = @_;
    
    my @bundle_list = get_dep_dlls ($script, $no_execute_flag);
    my @libs_to_pack;
    my %seen;

    my @target_libs = (
        @argv_linkers,
        @bundle_list,
    );
    while (my $lib = shift @target_libs) {
        say "ldd $lib";
        my $out = qx /ldd $lib/;
        warn qq["ldd $lib" failed\n]
          if not $? == 0;
          
        #  much of this logic is from PAR::Packer
        #  https://github.com/rschupp/PAR-Packer/blob/04a133b034448adeb5444af1941a5d7947d8cafb/myldr/find_files_to_embed/ldd.pl#L47
        my %dlls = $out =~ /^ \s* (\S+) \s* => \s* ( \/ \S+ ) /gmx;

      DLL:
        foreach my $name (keys %dlls) {
            if ($seen{$name}) {
                delete $dlls{$name};
                next DLL;
            }
            
            my $path = $dlls{$name};
            if (not -r $path) {
                warn qq[# ldd reported strange path: $path\n];
                delete $dlls{$name};
                next DLL;
            }
            #  system lib
            if ($path =~ m{^(?:/usr)?/lib(?:32|64)?/} ) {
                delete $dlls{$name};
                next DLL;
            }
            if ($path =~ m{\Qdarwin-thread-multi-2level/auto/share/dist/Alien\E}) {
                #  another alien
                delete $dlls{$name};
                next DLL;
            }
            
            $seen{$name}++;
        }
        push @libs_to_pack, values %dlls;
    }

    @libs_to_pack = sort @libs_to_pack;
    
    return wantarray ? @libs_to_pack : \@libs_to_pack;
}


#  needed for gdkpixbuf, when we support it 
sub find_so_files {
    my $target_dir = shift or die;

    my @files = File::Find::Rule->extras({ follow => 1, follow_skip=>2 })
                             ->file()
                             ->name( qr/\.so$/ )
                             ->in( $target_dir );
    return wantarray ? @files : \@files;
}


sub get_dll_skipper_regexp {
    #  PAR packs these automatically these days.
    my @skip = qw /
        perl5\d\d
        libstdc\+\+\-6
        libgcc_s_seh\-1
        libwinpthread\-1
        libgcc_s_sjlj\-1
    /;
    my $sk = join '|', @skip;
    my $qr_skip = qr /^(?:$sk)$RE_DLL_EXT$/;
    return $qr_skip;
}

#  find dependent dlls
#  could also adapt some of Module::ScanDeps::_compile_or_execute
#  as it handles more edge cases
sub get_dep_dlls {
    my ($script, $no_execute_flag) = @_;

    #  This is clunky:
    #  make sure $script/../lib is in @INC
    #  assume script is in a bin folder
    my $rlib_path = (path ($script)->parent->parent->stringify) . '/lib';
    #say "======= $rlib_path/lib ======";
    local @INC = (@INC, $rlib_path)
      if -d $rlib_path;
    
    my $deps_hash = scan_deps(
        files   => [ $script ],
        recurse => 1,
        execute => !$no_execute_flag,
        cache_file => $cache_file,
    );
    
    #my @lib_paths 
    #  = map {path($_)->absolute}
    #    grep {defined}  #  needed?
    #    @Config{qw /installsitearch installvendorarch installarchlib/};
    #say join ' ', @lib_paths;
    my @lib_paths
      = reverse sort {length $a <=> length $b}
        map {path($_)->absolute}
        @INC;

    my $paths = join '|', map {quotemeta} @lib_paths;
    my $inc_path_re = qr /^($paths)/i;
    #say $inc_path_re;

    #say "DEPS HASH:" . join "\n", keys %$deps_hash;
    my %dll_hash;
    my @aliens;
    foreach my $package (keys %$deps_hash) {
        my $details = $deps_hash->{$package};
        my @uses = @{$details->{uses} // []};
        if ($details->{key} =~ m{^Alien/.+\.pm$}) {
            push @aliens, $package;
        }
        next if !@uses;
        
        foreach my $dll (grep {$_ =~ $RE_DLL_EXT} @uses) {
            my $dll_path = $deps_hash->{$package}{file};
            #  Remove trailing component of path after /lib/
            if ($dll_path =~ m/$inc_path_re/) {
                $dll_path = $1 . '/' . $dll;
            }
            else {
                #  fallback, get everything after /lib/
                $dll_path =~ s|(?<=/lib/).+?$||;
                $dll_path .= $dll;
            }
            #say $dll_path;
            croak "either cannot find or cannot read $dll_path "
                . "for package $package"
              if not -r $dll_path;
            $dll_hash{$dll_path}++;
        }
    }
    #  handle aliens
  ALIEN:
    foreach my $package (@aliens) {
        next if $package =~ m{^Alien/(Base|Build)};
        my $package_inc_name = $package;
        $package =~ s{/}{::}g;
        $package =~ s/\.pm$//;
        if (!$INC{$package_inc_name}) {
            #  if the execute flag was off then try to load the package
            eval "require $package";
            if ($@) {
                say "Unable to require $package, skipping (error is $@)";
                next ALIEN;
            }
        }
        next ALIEN if !$package->can ('dynamic_libs');  # some older aliens might not be able to
        say "Finding dynamic libs for $package";
        foreach my $path ($package->dynamic_libs) {
            $dll_hash{$path}++;
        }
    } 
    
    my @dll_list = sort keys %dll_hash;
    return wantarray ? @dll_list : \@dll_list;
}
