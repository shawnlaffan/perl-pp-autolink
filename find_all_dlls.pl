use 5.010;
use File::Find::Rule;
use Path::Tiny;

#  skip anything under the C:\Windows folder
my $system_root = $ENV{SystemRoot};
my @exe_path = grep {(-e $_) && $_ !~ m|^\Q$system_root\E|i} split ';', $ENV{PATH};


my @files = File::Find::Rule->file()
                            ->name( '*.dll' )
                            ->maxdepth(1)
                            ->in( @exe_path );
                            
#say join "\n", @files;

my %file_hash;
foreach my $file (@files) {
    my $basename = path($file)->basename;
    $file_hash{$basename} //= $file;  #  we only want the first in the path
}

foreach my $file (sort keys %file_hash) {
    say "$file => $file_hash{$file}";
}