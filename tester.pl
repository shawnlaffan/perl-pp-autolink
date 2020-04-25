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
#Gtk2->init;

print "1\n";
