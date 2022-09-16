use strict;
use warnings;

BEGIN {
    if ($ENV{PAR_0}) {
        print "Adding $ENV{PAR_TEMP} to the path\n";
        use Config;
        $ENV{PATH} = "$ENV{PAR_TEMP}$Config{path_sep}$ENV{PATH}";
    }
};

#use Gtk2;
use Alien::proj;

print "1\n";
print "Alien::proj install type: "
     . Alien::proj->install_type
     . "\n";
print "Alien::proj dynamic libs: "
    . (join ' ', Alien::proj->dynamic_libs)
    . "\n";
print "end of script $0\n";
