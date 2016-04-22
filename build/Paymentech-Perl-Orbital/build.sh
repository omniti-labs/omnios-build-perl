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

BUILD_DEPENDS_IPS="omniti/perl/net-ssleay"

PREFIX=/opt/OMNIperl
reset_configure_opts

NO_PARALLEL_MAKE=1

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16 5.20"

# Add any additional deps here; OMNIperl added below
DEPENDS_IPS="omniti/perl/net-ssleay"

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
    "")
        logerr "You must specify a version with -d DEPVER. Valid versions: $PERLVERLIST"
        ;;
esac

buildperl32() {
    pushd $TMPDIR/$BUILDDIR > /dev/null
    logmsg "Building 32-bit"
    export ISALIST="$ISAPART"
    sudo /opt/OMNIperl/bin/perl ./bin/install_sdk --sdk=perl --destination $DESTDIR/opt/OMNIperl
    sudo mkdir -p $DESTDIR/opt/OMNIperl/lib/site_perl/$DEPVER/
    sudo mv /opt/OMNIperl/lib/site_perl/*/Paymentech $DESTDIR/opt/OMNIperl/lib/site_perl/$DEPVER/
    sudo chown -R root:bin $DESTDIR/opt
    sudo chmod 644 $DESTDIR/opt/OMNIperl/paymentech/logs/trans.log
    popd > /dev/null
    unset ISALIST
    export ISALIST 
}

init
test_if_core
download_source $PROG $PROG $VER
patch_source
prep_build
buildperl32
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
