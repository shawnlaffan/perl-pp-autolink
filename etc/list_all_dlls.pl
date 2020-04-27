use 5.010;
use strict;
use warnings;

use Carp;
use English qw / -no_match_vars/;

use File::Find::Rule;
use Path::Tiny       qw/ path /;


my $glob = $ARGV[0] || '*.dll';


my $env_sep  = $OSNAME =~ /MSWin/i ? ';' : ':';
my @exe_path = split $env_sep, $ENV{PATH};

my @system_paths;

if ($OSNAME =~ /MSWin32/i) {
    #  skip anything under the C:\Windows folder
    #  and no longer existent folders 
    my $system_root = $ENV{SystemRoot};
    @system_paths = grep {$_ =~ m|^\Q$system_root\E|i} @exe_path;
    @exe_path = grep {(-e $_) and $_ !~ m|^\Q$system_root\E|i} @exe_path;
    #say "PATHS: " . join ' ', @exe_path;
}

my @dll_files = File::Find::Rule->file()
                        ->name( $glob )
                        ->maxdepth(1)
                        ->in( @exe_path );

#say join "\n", @dll_files;


my %file_hash;
foreach my $file (@dll_files) {
    my $basename = path($file)->basename;
    $file_hash{$basename} //= $file;  #  we only want the first in the path
}

foreach my $file (sort keys %file_hash) {
    say "$file => $file_hash{$file}";
}
