package OmniTI::Package;

use strict;
use warnings;

use Data::Dumper;
use Dist::Metadata;
use File::Path qw( make_path );
use JSON;
use LWP::Simple;
use Module::CoreList;

our $VERSION = 0.1;

sub new {
    my ($class, %opts) = @_;

    my $self = {};

    $self->{'_recurse'} = $opts{'recurse'} || 0;
    $self->{'_get_deps'} = $opts{'deps'} || 0;

    $self->{'_build_deps'} = [];
    $self->{'_run_deps'} = [];
    $self->{'_full_deps'} = [];

    $self->{'_mod_cache'} = $opts{'cache'} && ref($opts{'cache'}) eq 'HASH' ? $opts{'cache'} : {};

    $self = bless $self, $class;

    if ($opts{'module'}) {
        $self->module($opts{'module'});
    } elsif ($opts{'dist'}) {
        $self->dist($opts{'dist'});
    } elsif ($opts{'archive'}) {
        $self->archive($opts{'archive'});
    }

    return $self;
}

sub builddeps {
    my ($self) = @_;

    return @{$self->{'_build_deps'}};
}

sub rundeps {
    my ($self) = @_;

    return @{$self->{'_run_deps'}};
}

sub fulldeps {
    my ($self) = @_;

    return @{$self->{'_full_deps'}};
}

sub module {
    my ($self, $module) = @_;

    return $self->{'_module'} if $self->{'_module'};

    my $res = get('http://search.cpan.org/api/module/' . $module) || die "Error contacting CPAN!";
    my $json = decode_json($res) || die "Bad response from CPAN!";

    die "CPAN error for $module: $json->{'error'}\n" if $json->{'error'};
    die "No distribution name found for $module!" unless $json->{'distvname'};

    $self->dist($json->{'distvname'});

    $self->{'_author'} = $json->{'cpanid'} if $json->{'cpanid'} && (!$self->{'_author'} || $self->{'_author'} eq 'UNKNOWN');;

    return $self->{'_module'};
}

sub dist {
    my ($self, $dist) = @_;

    return $self->{'_dist'} if $self->{'_dist'};

    my $res = get('http://search.cpan.org/api/dist/' . $dist) || die "Error contacting CPAN!";
    my $json = decode_json($res) || die "Bad response from CPAN!";

    die "CPAN error for $dist: $json->{'error'}\n" if $json->{'error'};
    die "No indication from CPAN which distribution is most recent for $dist!" unless $json->{'latest'};

    my $d = (grep { $_->{'distvname'} eq $json->{'latest'} } @{$json->{'releases'}})[0];

    die "Cannot find valid match for $dist in CPAN releases!" unless $d && ref($d) eq 'HASH';

    my $url = sprintf('http://search.cpan.org/CPAN/authors/id/%s/%s/%s/%s.tar.gz',
        substr($d->{'cpanid'}, 0, 1), substr($d->{'cpanid'}, 0, 2), $d->{'cpanid'},
        $d->{'distvname'});

    my $dir = _temp_dir($dist);

    my $file = qq{$dir/$d->{'distvname'}.tar.gz};

    getstore($url, $file) unless -f $file;

    die "Error downloading archive for $dist" unless -f $file;

    $self->archive($file);

    $self->{'_author'} = $d->{'cpanid'} if $d->{'cpanid'} && (!$self->{'_author'} || $self->{'_author'} eq 'UNKNOWN');;

    return $self->{'_dist'};
}

sub archive {
    my ($self, $archive) = @_;

    die "Invalid archive path provided!" if $archive && ! -f $archive;
    die "No archive present for package (maybe you new()'ed this with a module or distribution?)!"
        if !$archive && !$self->{'_archive'};

    if ($archive && -f $archive) {
        my $metadata = Dist::Metadata->new( file => $archive )->meta();

        $self->{'_archive'} = $archive;
        $self->{'_dist'} = $metadata->{'name'};
        $self->{'_module'} = (
            sort { length($a) <=> length($b) }
            grep { length($_) >= length($metadata->{'name'}) }
            keys %{$metadata->{'provides'}}
            )[0];
        $self->{'_provides'} = [keys %{$metadata->{'provides'}}];
        $self->{'_version'} = $metadata->{'version'};
        $self->{'_author'} = ($metadata->{'x_authority'} =~ m{cpan:(.*)})[0] if $metadata->{'x_authority'} && !$self->{'_author'};
        $self->{'_author'} = 'UNKNOWN' unless $self->{'_author'};
        $self->{'_summary'} = $metadata->{'abstract'};
        $self->{'_original_summary'} = $metadata->{'abstract'};

        if ($self->{'_get_deps'}) {
            foreach my $deptype (keys %{$metadata->{'prereqs'}}) {
                foreach my $req (keys %{$metadata->{'prereqs'}->{$deptype}}) {
                    next if $req eq 'conflicts';

                    foreach my $mod (keys %{$metadata->{'prereqs'}->{$deptype}->{$req}}) {
#printf STDERR ("Module: %-32s DepType: %-12s Req: %-12s Dep: %-32s\n", $self->module, $deptype, $req, $mod);

                        $self->add_dep('build', $mod);
                        $self->add_dep('run', $mod) if $deptype eq 'runtime';
                    }
                }
            }
        }
    }

    return $self->{'_archive'};
}

sub author {
    my ($self, $author) = @_;

    $self->{'_author'} = $author if defined $author;

    return $self->{'_author'};
}

sub summary {
    my ($self, $summary) = @_;

    $self->{'_summary'} = $summary if defined $summary;
    $self->{'_summary'} = $self->{'_original_summary'}
        if $self->{'_original_summary'} && defined $summary && !$summary;

    return $self->{'_summary'} || '(No summary available on CPAN)'
}

sub version {
    my ($self, $version) = @_;

    $self->{'_version'} = $version if defined $version;

    return $self->{'_version'};
}

sub provides {
    my ($self) = @_;

    return @{$self->{'_provides'}};
}

sub generate_build {
    my ($self, $rootdir, $overwrite) = @_;

    die "No base directory for build scripts provided!" unless $rootdir;
    die "Invalid base directory for build scripts: $rootdir" unless -d $rootdir;

    my $build_dir = $rootdir . $self->dist;
    $build_dir =~ s{/+}{/}g;

    # generate builds for any dependencies, as well
    foreach my $dep (@{$self->{'_build_deps'}}, @{$self->{'_run_deps'}}) {
        $dep->generate_build($rootdir, $overwrite);
    }

    if (-f "$build_dir/build.sh") {
        return unless defined $overwrite && $overwrite;
    }

    make_path($build_dir) unless -d $build_dir;

    # read template from DATA section, then reset seek position for the next generate_build call
    my $spos = tell DATA;
    my $template = join('',<DATA>);
    seek(DATA, $spos, 0);

    my %vars = (
        authorid    => $self->author,
        progname    => $self->dist,
        modname     => $self->module,
        version     => $self->version,
        summary     => $self->summary,
        deps_build  => join(' ', qw( developer/build/gnu-make system/header system/library/math/header-math ),
                            map { lc('omniti/perl/' . $_->dist) } $self->builddeps),
        deps_run    => join(' ', map { lc('omniti/perl/' . $_->dist) } $self->rundeps),
    );

    $template =~ s|\%$_\%|$vars{$_}|gs for keys %vars;

    open(my $fh, '>', "$build_dir/build.sh") || die "Error opening build file for writing: $!";
    print $fh $template;
    close($fh);
    chmod 0755, "$build_dir/build.sh";
}

sub add_dep {
    # Adds dependencies to the current package recursively. Each dependency will
    # itself be a full OmniTI::Package object. Skips any CORE dependencies.
    # Dependencies can be assured to be in the correct order for building since
    # we populate the deplist depth-first.
    my ($self, $list, $name, $recurse) = @_;

    # we don't add the current dist as a dep to itself
    return if $self->module eq $name;

    $recurse = 0 unless $recurse;
    $recurse = $self->{'_recurse'} if $self->{'_recurse'};

#    printf STDERR ("Module: %-32s List: %-6s Name: %-32s Recurse: %s\n", $self->module, $list, $name, $recurse);

    return if lc($name) eq 'perl';

    my $cache_name = $self->{'_mod_cache'}->{$name} ? $self->{'_mod_cache'}->{$name}->module() : $name;

    # short circuit if the dependency is already in the list
    return if grep { $_->module() eq $cache_name } @{$self->{"_${list}_deps"}};

    # skip adding to the deplist if this one's a CORE module
    my @core = Module::CoreList::find_modules($name);
    return if scalar(@core) > 0;

    # new dependency, so now the descent begins and we create a new object for it
    # which will trigger it to fill in its own dependencies, and so on, until there
    # is nothing in the list but CORE modules
    my $dep = exists $self->{'_mod_cache'}->{$name}
        ? $self->{'_mod_cache'}->{$name}
        : OmniTI::Package->new( module => $name, cache => $self->{'_mod_cache'}, deps => $recurse, recurse => $recurse );

    $self->{'_mod_cache'}->{$name} = $dep unless $self->{'_mod_cache'}->{$name};
    $self->{'_mod_cache'}->{$dep->module()} = $dep unless $self->{'_mod_cache'}->{$dep->module()};
    $self->{'_mod_cache'}->{$_} = $dep for $dep->provides();

#    printf STDERR ("[%s] _mod_cache keys dump:\n\t%s\n", $self->module, join(', ', sort keys %{$self->{'_mod_cache'}}));

#    if ($list eq 'build' && $recurse) {
#        my %seen;
#
#        my @t = @{$self->{'_build_deps'}};
#        $self->{'_build_deps'} = [];
#
#        foreach my $d ((@t, $dep->builddeps)) {
#            next if $seen{$d->module};
#            $seen{$d->module} = 1;
#            push(@{$self->{'_build_deps'}}, $d);
#        }
#    }
    push(@{$self->{'_build_deps'}}, $dep) if $list eq 'build';

#    printf STDERR ("Adding build dep %-32s to module %-32s\n", $dep->module, $self->module) if $list eq 'build';

#    if ($list eq 'run' && $recurse) {
#        my %seen;
#
#        my @t = @{$self->{'_run_deps'}};
#        $self->{'_run_deps'} = [];
#
#        foreach my $d ((@t, $dep->rundeps)) {
#            next if $seen{$d->module};
#            $seen{$d->module} = 1;
#            push(@{$self->{'_run_deps'}}, $d);
#        }
#    }
    push(@{$self->{'_run_deps'}}, $dep) if $list eq 'run';

#    printf STDERR ("Adding run   dep %-32s to module %-32s\n", $dep->module, $self->module) if $list eq 'run';

    foreach my $d ($dep->fulldeps) {
        push(@{$self->{'_full_deps'}}, $d) unless grep { $_->dist eq $d->dist } @{$self->{'_full_deps'}};
    }
    push(@{$self->{'_full_deps'}}, $dep) unless grep { $_->dist eq $dep->dist } @{$self->{'_full_deps'}};
}

sub _temp_dir {
    my ($dist) = @_;

    die "No distribution name provided!" unless $dist;

    my $dir = '/tmp/build_' . getpwuid($<) . "/$dist";
    make_path($dir);

    return $dir;
}

1;

# build.sh template
#
# Simple variable substitution performed for all %NAME% entries in the data
# below.

__DATA__
#!/usr/bin/bash
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright 2011-2012 OmniTI Computer Consulting, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Load support functions
. ../../lib/functions.sh

AUTHORID=%authorid%
PROG=%progname%
MODNAME=%modname%
VER=%version%
VERHUMAN=$VER
PKG=omniti/perl/$(echo $PROG | tr '[A-Z]' '[a-z]')
SUMMARY="%summary%"
DESC="$SUMMARY"

BUILD_DEPENDS_IPS="%deps_build%"

PREFIX=/opt/OMNIperl
reset_configure_opts

NO_PARALLEL_MAKE=1

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16"

# Add any additional deps here; omniti/runtime/perl added below
DEPENDS_IPS="%deps_run%"

# We require a Perl version to use for this build and there is no default
case $DEPVER in
    5.14)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-514-incorporation"
        ;;
    5.16)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-516-incorporation"
        ;;
    "")
        logerr "You must specify a version with -d DEPVER. Valid versions: $PERLVERLIST"
        ;;
esac

# Uncomment and set PREFIX if any modules install site binaries
#save_function make_isa_stub make_isa_stub_orig
#make_isa_stub() {
#    PREFIX=/usr make_isa_stub_orig
#}

init
test_if_core
download_source CPAN/authors/id/${AUTHORID:0:1}/${AUTHORID:0:2}/${AUTHORID} $PROG $VER
patch_source
prep_build
buildperl
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
