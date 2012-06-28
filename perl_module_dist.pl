#!/opt/OMNIperl/bin/perl

use strict;
use warnings;
use lib './lib/perl';
use OmniTI::Packaging::MetaCPAN::Module;
use OmniTI::Packaging::MetaCPAN::Dist;
use OmniTI::Packaging::Packages;
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
my @install = ($module);
my @dep_list = ($module);

my $p_obj = OmniTI::Packaging::Packages->new();
while (scalar(@dep_list)) {
    $module = pop @dep_list;

    my $m_obj = $module_cache{$module} || OmniTI::Packaging::MetaCPAN::Module->new( module => $module );
    my $d_obj = $dist_cache{$m_obj->dist()} || OmniTI::Packaging::MetaCPAN::Dist->new( dist => $m_obj->dist() );

    $module_cache{$module} = $m_obj;
    $dist_cache{$m_obj->dist()} = $d_obj;
    $dependencies{$module} = $d_obj->deps( module_cache => \%module_cache, pkg_obj => $p_obj );

    foreach my $dep ( @{$dependencies{$module}} ) {
        if ( ! grep { $_ eq $dep->{'dist'} } @install ) {
            unshift @install, $dep->{'dist'};
            push @dep_list, $dep->{'module'};
        }
    }
}

warn Dumper \@install;

exit 0;
