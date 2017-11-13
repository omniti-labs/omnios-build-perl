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

## This build includes a shared C library as well as Perl stuff.
## It delivers the C bits to /opt/omni and Perl bits to /opt/OMNIperl.

AUTHORID=ISAAC
PROG=libapreq2
MODNAME=APR::Request
VER=2.13
VERHUMAN=$VER
PKG=omniti/perl/$(echo $PROG | tr '[A-Z]' '[a-z]')
SUMMARY="wrapper for libapreq2's module/handle API. (Perl $DEPVER)"
DESC="$SUMMARY"

BUILD_DEPENDS_IPS="developer/build/gnu-make system/header system/library/math omniti/perl/extutils-xsbuilder omniti/perl/parse-recdescent omniti/server/apache22 omniti/server/apache22/mod_perl"

PREFIX=/opt/omni
export PREFIX
reset_configure_opts

NO_PARALLEL_MAKE=1
BUILDARCH=64
PERL64="/opt/OMNIperl/bin/$ISAPART64/perl"

CONFIGURE_OPTS="--enable-perl-glue"
CONFIGURE_OPTS_64="$CONFIGURE_OPTS_64
                   --with-perl=$PERL64
                   --with-apache2-apxs=/opt/apache22/bin/$ISAPART64/apxs"

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16 5.20"

# Add any additional deps here; omniti/runtime/perl added below
DEPENDS_IPS="omniti/perl/parse-recdescent"

# We require a Perl version to use for this build and there is no default
case $DEPVER in
    5.14)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-514-incorporation"
        ;;
    5.16)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-516-incorporation"
        ;;
    5.20)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-520-incorporation"
        ;;
    5.26)
        DEPENDS_IPS="$DEPENDS_IPS omniti/runtime/perl omniti/incorporation/perl-526-incorporation"
        ;;

    "")
        logerr "You must specify a version with -d DEPVER. Valid versions: $PERLVERLIST"
        ;;
esac

# Clean up a bloody mess. I am so ashamed.
chipotlaway() {
    logmsg "--- Rebuilding Perl dynamic libs properly (because MakeMaker hates us)"
    pushd $TMPDIR/$BUILDDIR/glue/perl > /dev/null
    logmsg "--- Running: \"gsed -i -e 's#^LDFLAGS =.*#LDFLAGS =#' -e 's#^OTHERLDFLAGS =.*#OTHERLDFLAGS =#' -e 's#-R/tmp/build[^ \t]*\.libs\>##g'\" on all the Makefiles"
    gsed -i \
        -e 's#^LDFLAGS =.*#LDFLAGS =#' \
        -e 's#^OTHERLDFLAGS =.*#OTHERLDFLAGS =#' \
        -e 's#-R/tmp/build[^ \t]*\.libs\>##g' \
        $(find . -name Makefile) || \
            logerr "--- Makefile fix-up failed"
    logcmd rm -rf blib/ || \
        logerr "------ Unable to remove previous build products"
    logcmd $MAKE || \
        logerr "------ Re-make failed"
    # This stuff is going to get shat on again during "make install" so we stash it
    logmsg "------ Stashing dynamic libs"
    pushd blib > /dev/null
    logcmd mkdir -p $TMPDIR/chipotlaway/arch/auto/APR/Request/{Apache2,CGI,Cookie,Error,Hook,Param,Parser} || \
        logerr "------ Failed to make stash directory tree"
    for file in $(find arch/auto/APR -name '*.so') ; do \
        cp $file $TMPDIR/chipotlaway/$file || logerr "------ Failed to copy $file" ; done
    popd > /dev/null
    popd > /dev/null
}

save_function make_prog make_prog_orig
make_prog() {
    make_prog_orig
    chipotlaway
}

# Install to the Perl vendorlib path
make_install() {
    logmsg "--- make install"
    logcmd $MAKE DESTDIR=${DESTDIR} INSTALLDIRS=vendor install || \
        logerr "--- Make install failed"
}

install_so() {
    logmsg "Restoring the known-good dynamic libs"
    DESTPATH=$($PERL64 -MConfig -e'print $Config{vendorarch}')
    pushd $TMPDIR/chipotlaway/arch > /dev/null
    for file in $(find auto/APR -name '*.so') ; do \
        cp -f $file $DESTDIR/$DESTPATH/$file || logerr "--- Failed to copy $file"; done
    logmsg "--- Copy complete, removing stash dir"
    logcmd rm -rf $TMPDIR/chipotlaway
    popd > /dev/null
}

# Uncomment and set PREFIX if any modules install site binaries
#save_function make_isa_stub make_isa_stub_orig
#make_isa_stub() {
#    PREFIX=/usr make_isa_stub_orig
#}

init
download_source CPAN/authors/id/${AUTHORID:0:1}/${AUTHORID:0:2}/${AUTHORID} $PROG $VER
patch_source
prep_build
build
install_so
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
