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

    $tmpl_header = read_file("$args{'build_root'}/template/perl/header");
    $tmpl_footer = read_file("$args{'build_root'}/template/perl/footer");

    if ( ! -d "$args{'build_root'}/build/$dist" ) {
        mkdir "$args{'build_root'}/build/$dist" or die "could not make dist build dir $args{'build_root'}/build/$dist $!\n";
        mkdir "$args{'build_root'}/build/$dist/patches" or die "could not make patches dir $args{'build_root'}/build/$dist/patches $!\n";
    }

    open BUILDSH, ">$args{'build_root'}/build/$dist/build.sh" or die "could not open $args{'build_root'}/build/$dist/build.sh $!\n";
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
    chmod 0755, "$args{'build_root'}/build/$dist/build.sh";
}
