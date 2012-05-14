#!/opt/OMNIperl/bin/perl

use strict;
use Getopt::Long;
use File::Slurp qw(read_file);

my ($module, $author, $dist, $ver, $summary, $help) = (undef,undef,undef,undef,undef,0);
my ($tmpl_header, $tmpl_footer);

GetOptions(
    "m|module=s" => \$module,
    "a|author=s" => \$author,
    "d|dist=s" => \$dist,
    "v|ver=s" => \$ver,
    "s|summary=s" => \$summary,
    "h|help" => sub { $help++; }
);

if ( $help || ! $module || ! $author || ! $dist || ! $ver || ! $summary ) {
    print "Usage:\n";
    print "\t-m Module (ex. Foo::Bar) used to test if module exists in Core\n";
    print "\t-a Author ID capatalized (ex. NEOPHENIX)\n";
    print "\t-d Dist (ex. Foo-Bar libwww-perl)\n";
    print "\t-v Version (ex. 6.04)\n";
    print "\t-s Summary (ex. \"This is a module that does stuff\")\n";
    print "\t-meta Pull info from MetaCPAN, requires -m\n";
    print "\t-h This help\n";
    exit 0;
}

$tmpl_header = read_file("template/perl/header");
$tmpl_footer = read_file("template/perl/footer");

if ( ! -d "build/$dist" ) {
    mkdir "build/$dist" or die "could not make dist build dir build/$dist $!\n";
    mkdir "build/$dist/patches" or die "could not make patches dir build/$dist/patches $!\n";
}

open BUILDSH, ">build/$dist/build.sh" or die "could not open build/$dist/build.sh $!\n";
print BUILDSH $tmpl_header;
print BUILDSH "AUTHORID=$author\n";
print BUILDSH "PROG=$dist\n";
print BUILDSH "MODNAME=$module\n";
print BUILDSH "VER=$ver\n";
print BUILDSH "VERHUMAN=\$VER\n";
print BUILDSH "PKG=omniti/perl/\$(echo \$PROG | tr '[A-Z]' '[a-z]')\n";
print BUILDSH "SUMMARY=\"$summary\"\n";
print BUILDSH "DESC=\"$summary\"\n";
print BUILDSH $tmpl_footer;
close BUILDSH;
chmod 0755, "build/$dist/build.sh";

exit 0;
