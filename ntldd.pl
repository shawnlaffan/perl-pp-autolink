use 5.010;
use Path::Tiny;
use Alien::gdal;

$ENV{PATH} .= ';' . Alien::gdal->bin_dir;

use Win32::Ldd qw(pe_dependencies);
 
my $sys_root = path (lc $ENV{SystemRoot});
my @path = grep {not $sys_root->subsumes(lc $_)} split ';', $ENV{PATH};

my $target = 'C:\berrybrew\5.28.0_64_PDL\perl\bin\s1sgdk-win32-2.0-0.dll';
$target = 'C:\berrybrew\5.28.0_64_PDL\perl\site\lib\auto\share\dist\Alien-gdal\bin\gdal_grid.exe';

$dep_tree = pe_dependencies(
    $target,
    search_paths => \@path,
    recursive    => 0,  #  has no effect?
);


#foreach my $key (keys %$dep_tree) {
#    say $key . ' ' . ($dep_tree->{$key} // '');
#}

my @children = @{$dep_tree->{children}};
my %done = (
    $dep_tree->{resolved_module} => 1,
);


foreach my $child (@children) {
    my $resolved_module = $child->{resolved_module};
    next if !$resolved_module || $done{$resolved_module};
    next if $sys_root->subsumes(path(lc $resolved_module));
    #say $resolved_module;
    
    next if !$child->{children};
    push @children, @{$child->{children}};
    $done{$resolved_module}++;
    #say ';;';
}

say '::::::::::::::::::';
say join "\n", sort keys %done; 