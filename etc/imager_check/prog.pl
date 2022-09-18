#  script from sciurus
#  https://github.com/rschupp/PAR-Packer/issues/67
use strict;
use warnings;
use FindBin qw /$Bin/;
use Imager;

my $image = Imager->new(xsize => 100, ysize => 100);

$image->box(xmin => 0, ymin => 0, xmax => 99, ymax => 99,
            filled => 1, color => 'blue');
$image->box(xmin => 20, ymin => 20, xmax => 79, ymax => 79,
            filled => 1, color => 'green');

my $font_filename = "$Bin/FreeSansBold.ttf";
if ( $ENV{PAR_0} ) {
    $font_filename = $ENV{PAR_TEMP} . "/inc/" . $font_filename;
	die "no file" if !-e $font_filename;
}

my $font = Imager::Font->new(file=>$font_filename)
  or die "Cannot load $font_filename: ", Imager->errstr;

my $text = "Hello Boxes!";
my $text_size = 12;

$font->align(string  => $text,
             size    => $text_size,
             color   => 'red',
             x	     => $image->getwidth/2,
             y	     => $image->getheight/2,
             halign  => 'center',
             valign  => 'center',
             image   => $image);

$image->write(file=>'tut2.png')
    or die 'Cannot save tut2.png: ', $image->errstr;

