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

PROG=perl-5160-incorporation
VER=5.16.0
VERHUMAN=$VER
PKG=omniti/incorporation/perl-5160-incorporation
SUMMARY="This is the old 5.16 incorporation, superseded by perl-516-incorporation"
DESC="$SUMMARY"

#DEPENDS_IPS="=omniti/runtime/perl@5.16.0"

init
prep_build
# There is nothing installed, this is just metadata
unset DESTDIR
make_package
clean_up

# Vim hints
# vim:ts=4:sw=4:et:
