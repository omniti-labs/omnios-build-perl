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

PROG=Paymentech-Perl-Orbital
MODNAME=Paymentech-Perl-Orbital
VER=7.4.0
VERHUMAN=$VER
PKG=omniti/perl/$(echo $PROG | tr '[A-Z]' '[a-z]')
SUMMARY="Paymentech Perl Orbital (Perl $DEPVER)"
DESC="$SUMMARY"
#PERL_MAKE_TEST="" #broken tests
BUILD_DEPENDS_IPS="omniti/perl/net-ssleay"
PREFIX=/opt/OMNIperl
reset_configure_opts

NO_PARALLEL_MAKE=1

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16 5.20 5.26"

# Add any additional deps here; OMNIperl added below
DEPENDS_IPS="omniti/perl/net-ssleay"

export PAYMENTECH_HOME=$DESTDIR/opt/paymentech

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

pre_copy() {
    pushd $TMPDIR/$PROG-$VER > /dev/null
    logmsg "PRE_COPY"
    export ISALIST="$ISAPART"
    #Paymentech-Perl-Orbital-7.4.0
    logmsg "sudo cp -r $TMPDIR/$PROG-$VER/paymentech /opt/"
    sudo cp -r $TMPDIR/$PROG-$VER/paymentech /opt/
    popd > /dev/null
    unset ISALIST
    export ISALIST

}
make_opt() {
    pushd $TMPDIR/$BUILDDIR > /dev/null
    logmsg "Making opt/paymentech"
    export ISALIST="$ISAPART"
    sudo mkdir $DESTDIR/opt/paymentech
    sudo cp -r $TMPDIR/$BUILDDIR/paymentech $DESTDIR/opt/
    popd > /dev/null
    unset ISALIST
    export ISALIST
}

# Uncomment and set PREFIX if any modules install site binaries
save_function make_isa_stub make_isa_stub_orig
make_isa_stub() {
    PREFIX=/opt make_isa_stub_orig
}


build() {
    pushd $TMPDIR/$BUILDDIR > /dev/null
    logmsg "Building "
    make_clean
    logmsg "--- Makefile.PL"
    logcmd /opt/OMNIperl/bin/perl Makefile.PL PREFIX=/opt/OMNIperl INSTALLDIRS=vendor MAKE=gmake || \
        logerr "--- Makefile.PL failed"
    patch_source
    logmsg "--- make"
    logcmd gmake || logerr "--- make failed"
    logmsg "--- make test"
    logcmd gmake test || logerr "--- gmake test filaed"
    logmsg "--- make install"
    logcmd gmake DESTDIR=${DESTDIR} install || logerr "--- make install failed"
    popd > /dev/null
}


init
test_if_core
download_source $PROG $PROG $VER
#patch_source #moved to run after `perl Makefile.pl` to apply changes to Makefile
prep_build
pre_copy
build
make_opt
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
