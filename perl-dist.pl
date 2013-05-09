#!/opt/OMNIperl/bin/perl

use strict;
use warnings;

$| = 1;

use Getopt::Long;

use File::Basename;
my $rootdir = dirname(__FILE__);

eval <<EOE;
    use lib "$rootdir/lib/perl";
    use OmniTI::Package;
EOE

die <<EOD if $@;
An error was encountered trying to load the packaging libraries. This
is most frequently because there are missing dependencies. On OmniOS,
you may be able to fix this via the following:

    sudo pkg install omniti/perl/dist-metadata omniti/perl/libwww-perl

The full error was:

$@
EOD

my ($help, $recurse, $buildcore, @mods, @dists, @files);

exit usage() unless GetOptions(
    'help|h'          => \$help,
    'recurse|r'       => \$recurse,
    'build-core'      => \$buildcore,
    'module|mod|m:s'  => \@mods,
    'dist|d:s'        => \@dists,
    'package|file|f:s'=> \@files,
);

$recurse = 0 unless $recurse && $recurse == 1;

exit usage() if $help || (scalar(@mods) == 0 && scalar(@dists) == 0 && scalar(@files) == 0);;

my $mod_cache = {};
my %already_built = ();
my @new_dists = ();

open(my $fh, "$rootdir/perl-build-order.txt") || die "Error opening build order file: $!\n";
while (my $l = <$fh>) {
    chomp($l);
    $already_built{$l} = 1;
}
close($fh);

if (@mods) {
    foreach my $module (@mods) {
        my $p = OmniTI::Package->new( module => $module, cache => $mod_cache, deps => 1, recurse => $recurse );

        if ($p->core) {
            show_core($p);
            next unless $buildcore;
        }

        $p->generate_build("$rootdir/build/");

        show_summary($p);
        already_built($p->dist);
    }
}

if (@dists) {
    foreach my $dist (@dists) {
        my $p = OmniTI::Package->new( dist => $dist, cache => $mod_cache, deps => 1, recurse => $recurse );

        if ($p->core) {
            show_core($p);
            next unless $buildcore;
        }

        $p->generate_build("$rootdir/build/");

        show_summary($p);
        already_built($p->dist);
    }
}

if (@files) {
    foreach my $file (@files) {
        die "Invalid path provided for local archive: $file\n" unless -f $file;

        my $p = OmniTI::Package->new( archive => $file, cache => $mod_cache, deps => 1, recurse => $recurse );

        if ($p->core) {
            show_core($p);
            next unless $buildcore;
        }

        $p->generate_build("$rootdir/build/");

        show_summary($p);
        already_built($p->dist);
    }
}

if (scalar(@new_dists) == 0) {
    print "Nothing to do.\n";
    exit 0;
}

printf("The following distributions are new:\n");
printf("    %s\n", $_) for @new_dists;

my @need_licenses = grep { !-f "$rootdir/build/$_/local.mog" } @new_dists;

if (scalar(@need_licenses) > 0) {
    printf("\nLicenses are unresolved for:\n");
    printf("    %s\n", $_) for @need_licenses;
}

sub show_core {
    my ($p) = @_;

    if ($buildcore) {
        printf("Module %s is CORE. Building anyway (--build-core provided), but please make\n".
               "sure you know what you're doing and that this module is safe to package\n".
               "separately.\n\n", $p->module);
    } else {
        printf("Module %s is CORE. Skipping.\n\n", $p->module);
    }
}

sub show_summary {
    my ($p) = @_;

    my $i = 0;

    printf("Module:       %s\n", $p->module);
    printf("Distribution: %s\n", $p->dist);
    printf("Version:      %s\n", $p->version);
    printf("Depends on:");
    printf("%s %-2s%s\n",
        ($i++ != 0 ? ' ' x 11 : ''),
        already_built($_->dist) ? '' : '*',
        $_->dist) for $p->fulldeps;
    print "\n";
}

sub already_built {
    my ($dist) = @_;

    return 1 if exists $already_built{$dist};

    push(@new_dists, $dist) unless grep { $_ eq $dist } @new_dists;

    return 0;
}

sub usage {
    my $prog = basename(__FILE__);

    print <<EOU;
$prog - Generate build scripts for creating omniti-perl IPS packages.

    --module  -m    Module name to package.

    --dist    -d    Distribution name to package.

    --file    -f    Local archive file to inspect and package.

    --recurse -r    Follow dependencies of dependencies of ...

    --build-core    Ignores check for CORE modules and creates build
                    scripts for them anyway. Use with caution.

    --help    -h    Display this message and exit.

You may use any of the -m, -d, and -f arguments concurrently, and each
multiple times.

EOU
}

