package OmniTI::Packaging::IPS;

use strict;
use warnings;
use File::Slurp qw(read_file);

=pod

Currently just makes a build/<dist>/build.sh file

=cut

sub create_buildsh {
    my %args = @_;

    die "need dist" if ( ! $args{'dist'} );
    die "need author" if ( ! $args{'author'} );
    die "need version" if ( ! $args{'version'} );
    die "need module" if ( ! $args{'module'} );
    die "need summary" if ( ! $args{'summary'} );
    die "need a build_root dir" if ( ! $args{'build_root'} );

    my $tmpl_header = read_file("$args{'build_root'}/template/perl/header");
    my $tmpl_footer = read_file("$args{'build_root'}/template/perl/footer");

    if ( ! -d "$args{'build_root'}/build/$args{'dist'}" ) {
        mkdir "$args{'build_root'}/build/$args{'dist'}" or die "could not make dist build dir $args{'build_root'}/build/$args{'dist'} $!\n";
        mkdir "$args{'build_root'}/build/$args{'dist'}/patches" or die "could not make patches dir $args{'build_root'}/build/$args{'dist'}/patches $!\n";
    }

    if ( $args{'dependencies'} ) {
        my @deps;
        foreach my $dep ( @{$args{'dependencies'}} ) {
            $dep = 'omniti/perl/'.$dep if ( $dep !~ /^omniti\/perl/ );
            push @deps, $dep;
        }
        my $depends = "DEPENDS_IPS=" . join(" ", @deps);

        $tmpl_footer =~ s/#DEPENDS_IPS=/$depends/;
    }

    open BUILDSH, ">$args{'build_root'}/build/$args{'dist'}/build.sh" or die "could not open $args{'build_root'}/build/$args{'dist'}/build.sh $!";
    print BUILDSH $tmpl_header;
    print BUILDSH "AUTHORID=$args{'author'}\n";
    print BUILDSH "PROG=$args{'dist'}\n";
    print BUILDSH "MODNAME=$args{'module'}\n";
    print BUILDSH "VER=$args{'version'}\n";
    print BUILDSH "VERHUMAN=\$VER\n";
    print BUILDSH "PKG=omniti/perl/\$(echo \$PROG | tr '[A-Z]' '[a-z]')\n";
    print BUILDSH "SUMMARY=\"$args{'summary'}\"\n";
    print BUILDSH "DESC=\"$args{'summary'}\"\n";
    print BUILDSH $tmpl_footer;
    close BUILDSH;
    chmod 0755, "$args{'build_root'}/build/$args{'dist'}/build.sh";
}

sub write_license {
    my %args = @_;

    die "need dist" if ( ! $args{'dist'} );
    die "need contents" if ( ! $args{'contents'} );
    die "need a build_root dir" if ( ! $args{'build_root'} );

    open LICENSE, ">$args{'build_root'}/build/$args{'dist'}/local.mog" or die "could not open $args{'build_root'}/build/$args{'dist'}/local.mog $!";
    print LICENSE $args{'contents'};
    close LICENSE;
}

1;
