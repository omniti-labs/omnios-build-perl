package CPANPLUS::Dist::IPS;

use strict;
use base 'CPANPLUS::Dist::Base';

my $SUNOSVER    = `uname -r`;
my $PVER        = 0.151002;
chomp($SUNOSVER);

my $PKGSEND     = "/usr/bin/pkgsend";
my $PKGMOG      = "/usr/bin/pkgmogrify";
my $PKGFMT      = "/usr/bin/pkgfmt";

my $GLOBALMOG   = "lib/global-transforms.mog";
my $CPPMOG      = "lib/cpanplus.mog";

(my $PERLVER = $^V) =~ s/[v\.]//g;

sub format_available {
    # Basic checks to see if we have the various binaries to do this
    if (
        -f $PKGSEND &&
        -f $PKGMOG &&
        -f $PKGFMT
    ) {
        return 1;
    }
    return 0;
}

sub prepare {
    my $dist    = shift;
    my $mod_obj = $dist->parent();
    my $int_obj = $mod_obj->parent();

    # TODO why the f$*k doesn't this work when not called via cpan2dist?
    $dist->SUPER::prepare( @_ ) or return;

    # Setup IPS mog file
    my $authorid    = $mod_obj->author()->cpanid();
    my $package     = $mod_obj->package_name();
    my $module      = $mod_obj->module();
    my $version     = $mod_obj->version();
    my $ips_pkg     = "omniti/perl/" . lc($package);
    my $summary     = $mod_obj->description();

    my $fmri        = lc($package)."\@$version,$SUNOSVER-$PVER";

    open MOG, ">$package.mog" or die "Could not create $package.mog: $!\n";
    print MOG "set name=pkg.fmri value=$fmri\n";
    print MOG "set name=pkg.human-version value=\"$version\"\n";
    print MOG "set name=pkg.summary value=\"$summary\"\n";
    print MOG "set name=pkg.descr value=\"$summary\"\n";
    print MOG "set name=publisher value=\"sa\@omniti.com\"\n";

    # DEPENDENCIES
    print MOG "depend type=require fmri=omniti/incorporation/perl-$PERLVER-incorporation\n";
    my $prereqs = $mod_obj->status()->prereqs();
    foreach my $prereq ( keys %{$prereqs} ) {
        my $obj = $int_obj->module_tree($prereq);
        next if ( ! $obj || $obj->module_is_supplied_with_perl_core() );
        print MOG "depend type=require fmri=omniti/perl/".lc($obj->package())."\n";
    }
    # TODO Find License
    close MOG;

    return $dist->status->prepared(1);
}

sub create {
    my $dist = shift;
    my $mod_obj = $dist->parent();

    $dist->SUPER::create( @_ ) or return;

    my $package = $mod_obj->package_name();
    my $mog     = "$package.mog";
    my $p5m_int = "$package.p5m.int";
    my $p5m     = "$package.p5m";
    my $blib    = $dist->status()->dist()."/blib";

    my $cmd = "$PKGSEND generate $blib > $p5m_int";
    system($cmd);
    $cmd = "$PKGMOG $p5m_int $mog $GLOBALMOG $CPPMOG | $PKGFMT -u > $p5m";
    system($cmd);

    #system($PKGSEND, "publish", blah blah blah);

    return $dist->status->created(0);
}

sub install {
    my $dist = shift;

    return $dist->status->installed(0);
}

sub uninstall {
    my $dist = shift;

    return $dist->status->uninstalled(0);
}

1;
