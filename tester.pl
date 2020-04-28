use strict;
use warnings;

BEGIN {
    if ($ENV{PAR_0}) {
        print "Adding $ENV{PAR_TEMP} to the path\n";
        use Config;
        $ENV{PATH} = "$ENV{PAR_TEMP}$Config{path_sep}$ENV{PATH}";
    }
};

use Gtk2;
use Alien::sqlite;

print "1\n";
print "Alien::sqlite install type: "
     . Alien::sqlite->install_type
     . "\n";
print "Alien::sqlite dynamic libs: "
    . (join ' ', Alien::sqlite->dynamic_libs)
    . "\n";
print "end of script $0\n";
