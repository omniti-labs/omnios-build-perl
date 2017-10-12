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

AUTHORID=HANK
PROG=Text-Aspell
MODNAME=Text::Aspell
VER=0.09
VERHUMAN=$VER
PKG=omniti/perl/$(echo $PROG | tr '[A-Z]' '[a-z]')
SUMMARY="Perl interface to the GNU Aspell library (Perl $DEPVER)"
DESC="$SUMMARY"

BUILD_DEPENDS_IPS="developer/build/gnu-make system/header system/library/math omniti/library/aspell omniti/library/aspell/aspell-en"

PREFIX=/opt/OMNIperl

NO_PARALLEL_MAKE=1

# Only 5.14 and later will get individual module builds
PERLVERLIST="5.14 5.16 5.20"

# Add any additional deps here; omniti/runtime/perl added below
DEPENDS_IPS="omniti/library/aspell omniti/library/aspell/aspell-en"

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

# Brute force, since Makefile.PL isn't pulling the perl config for some reason
## 32-bit CCFLAGS generated with:
## /opt/OMNIperl/bin/i386/perl -MConfig -e 'print "$Config{ccflags}"'
makefilepl32() {
    logmsg "--- Makefile.PL 32-bit"
    logcmd $PERL32 Makefile.PL PREFIX=$PREFIX INSTALLDIRS=vendor \
            INC="-I/opt/omni/include" \
            CCFLAGS="-D_REENTRANT -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_TS_ERRNO \
                     -DPTR_IS_LONG -fno-strict-aliasing -pipe -D_LARGEFILE_SOURCE \
                     -D_FILE_OFFSET_BITS=64 -DPERL_USE_SAFE_PUTENV" \
            LDDLFLAGS="-shared -L/opt/omni/lib -R/opt/omni/lib -laspell" $@ ||
        logerr "Failed to run Makefile.PL"
}

## 64-bit CCFLAGS generated with:
## /opt/OMNIperl/bin/amd64/perl -MConfig -e 'print "$Config{ccflags}"'
makefilepl64() {
    logmsg "--- Makefile.PL 64-bit"
    logcmd $PERL64 Makefile.PL PREFIX=$PREFIX INSTALLDIRS=vendor \
            INC="-I/opt/omni/include" \
            CCFLAGS="-m64 -D_REENTRANT -D_LARGEFILE64_SOURCE -D_TS_ERRNO \
                     -DPTR_IS_LONG -fno-strict-aliasing -pipe -D_LARGEFILE_SOURCE \
                     -D_FILE_OFFSET_BITS=64 -DPERL_USE_SAFE_PUTENV" \
            LDDLFLAGS="-shared -L/opt/omni/lib/$ISAPART64 -R/opt/omni/lib/$ISAPART64 -laspell" $@ ||
        logerr "Failed to run Makefile.PL"
}

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
