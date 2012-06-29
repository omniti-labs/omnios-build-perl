#!/opt/OMNIperl/bin/perl

use strict;
use warnings;
use lib './lib/perl';
use OmniTI::Packaging::MetaCPAN::Module;
use OmniTI::Packaging::MetaCPAN::Dist;
use OmniTI::Packaging::Packages;
use OmniTI::Packaging::IPS;
use Getopt::Long;
use File::Slurp qw(read_file);
use Data::Dumper;
use JSON;

my ($module, $help) = (undef,0);
my ($tmpl_header, $tmpl_footer);

GetOptions(
    "m|module=s" => \$module,
    "h|help" => sub { $help++; }
);

if ( $help || ! $module ) {
    print "Usage:\n";
    print "\t-m Module (ex. Foo::Bar) used to test if module exists in Core\n";
    print "\t-h This help\n";
    exit 0;
}

my %module_cache = ();
my %dist_cache = ();
my %dependencies = ();
my @install = ();
my @dep_list = ($module);
my @unknown_licenses = ();

my $p_obj = OmniTI::Packaging::Packages->new();
while (scalar(@dep_list)) {
    my $mod = pop @dep_list;

    my $m_obj = $module_cache{$mod} || OmniTI::Packaging::MetaCPAN::Module->new( module => $mod );
    my $d_obj = $dist_cache{$m_obj->dist()} || OmniTI::Packaging::MetaCPAN::Dist->new( dist => $m_obj->dist() );

    $module_cache{$mod} = $m_obj;
    $dist_cache{$m_obj->dist()} = $d_obj;
    $dependencies{$mod} = $d_obj->deps( module_cache => \%module_cache, pkg_obj => $p_obj );

    foreach my $dep ( @{$dependencies{$mod}} ) {
        if ( ! grep { $_ eq $dep->{'dist'} } @install ) {
            unshift @install, $dep->{'dist'};
            push @dep_list, $dep->{'module'};
        }
    }

    OmniTI::Packaging::IPS::create_buildsh(
        build_root      => '/home/bclapper/build/',
        dist            => $m_obj->dist(),
        author          => $m_obj->author(),
        version         => $m_obj->version(),
        module          => $mod,
        summary         => $m_obj->summary(),
        dependencies    => [map { $_->{'dist'} } @{$dependencies{$mod}}]
    );

    my $license;
    eval {
        $license = $d_obj->license_for_mog();
        OmniTI::Packaging::IPS::write_license(
            build_root      => '/home/bclapper/build/',
            dist            => $m_obj->dist(),
            contents        => $license
        );
    };
    if ( $@ || ! $license ) {
        push @unknown_licenses, $m_obj->dist();
    }
}

if ( scalar(@unknown_licenses) ) {
    print "Unknown Licenses, you will need to fix these manually:\n";
    map { print "\t$_\n"; } @unknown_licenses;
}

push @install, $module_cache{$module}->dist();
print "Installation order:\n";
map { print "$_\n"; } @install;

exit 0;
