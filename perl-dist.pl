#!/opt/OMNIperl/bin/perl

use strict;
use warnings;

use Getopt::Long;

use File::Basename;
my $rootdir = dirname(__FILE__);

eval <<EOE;
    use lib "$rootdir/lib/perl";
    use OmniTI::Package;
EOE

my ($help, @mods, @dists, @files);

exit usage() unless GetOptions(
    'help|h'          => \$help,
    'module|mod|m:s'  => \@mods,
    'dist|d:s'        => \@dists,
    'package|file|f:s'=> \@files,
);

exit usage() if $help || (scalar(@mods) == 0 && scalar(@dists) == 0 && scalar(@files) == 0);;

my $mod_cache = {};

if (@mods) {
    foreach my $module (@mods) {
        my $p = OmniTI::Package->new( module => $module, cache => $mod_cache, deps => 1 );
        $p->generate_build("$rootdir/build/");

        show_summary($p);
    }
}

if (@dists) {
    foreach my $dist (@dists) {
        my $p = OmniTI::Package->new( dist => $dist, cache => $mod_cache, deps => 1 );
        $p->generate_build("$rootdir/build/");

        show_summary($p);
    }
}

if (@files) {
    foreach my $file (@files) {
        die "Invalid path provided for local archive: $file\n" unless -f $file;

        my $p = OmniTI::Package->new( archive => $file, cache => $mod_cache, deps => 1 );
        $p->generate_build("$rootdir/build/");

        show_summary($p);
    }
}

sub show_summary {
    my ($p) = @_;

    my $i = 0;

    printf("Module:       %s\n", $p->module);
    printf("Distribution: %s\n", $p->dist);
    printf("Version:      %s\n", $p->version);
    printf("Depends on:");
    printf("%s   %s\n", ($i++ != 0 ? ' ' x 11 : ''), $_->dist) for $p->builddeps;
    print "\n";
}

sub usage {
    my $prog = basename(__FILE__);

    print <<EOU;
$prog - Generate build scripts for creating omniti-perl IPS packages.

    --module -m     Module name to package.

    --dist   -d     Distribution name to package.

    --file   -f     Local archive file to inspect and package.

    --help   -h     Display this message and exit.

You may use any of the -m, -d, and -f arguments concurrently, and each
multiple times.

EOU
}

