# Package server URL and publisher
PKGPUBLISHER=perl.omniti.com

# This URI is here for information about where we publish
# our perl modules. You should never publish straight to
# this repo because we require all packages to be signed.
#PKGSRVR=http://pkg-il-1.int.omniti.net:10008/

# This line will create a on-disk repo in
# the top level of your checkout and publish there instead
# of the URI specified above.
#
# The directory does not need to exist ahead of time.
#
PKGSRVR=file:///$MYDIR/../tmp.repo/
