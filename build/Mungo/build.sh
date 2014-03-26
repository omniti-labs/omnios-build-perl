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

PROG=Mungo
MODNAME=Mungo
VER=1.1.122
VERHUMAN=$VER
PKG=omniti/perl/$(echo $PROG | tr '[A-Z]' '[a-z]')
SUMMARY="an 'anti-framework' to make programming web pages under mod_perl as accessible as php."
DESC="$SUMMARY"

BUILD_DEPENDS_IPS="developer/build/gnu-make system/header system/library/math/header-math omniti/perl/html-parser omniti/server/apache22 omniti/server/apache22/mod_perl"

PREFIX=/opt/OMNIperl
reset_configure_opts

BUILDARCH=64
NO_PARALLEL_MAKE=1
PERL_MAKE_TEST=""
APXS="/opt/apache22/bin/$ISAPART64/apxs"
export APXS

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16"

# Add any additional deps here; OMNIperl added below
DEPENDS_IPS="omniti/perl/html-parser omniti/server/apache22/mod_perl"

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
download_source $PROG $PROG $VER
patch_source
prep_build
buildperl
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
