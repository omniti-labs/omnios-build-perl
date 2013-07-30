# Packaging Perl Distributions for OmniOS

We deliver Perl module distributions as IPS packages and make them available via 
the __perl.omniti.com__ publisher.

For a more detailed explanation of IPS packaging, please see the [IPS Dev 
 Guide](http://hub.opensolaris.org/bin/download/Project+pkg/files/ipsdevguide.pdf), 
 particularly Chapter 3, which will explain the terminology.

We currently (Aug 2012) build packages for both perl 5.14 and 5.16 .  Please make sure that you publish packages for both versions when building a new dist.

## How This Repository is Structured

The Perl build repo is laid out like other OmniOS build repos, with some 
additional code to facilitate metadata processing, particularly dependency 
resolution.  In the root directory, `perl-dist.pl` is used to make new 
build scripts.  The build scripts themselves live in the "build" subdirectory.

The bulk of the build work is done via two shell files in lib, config.sh and 
functions.sh.  You should not need to change anything directly in these files.  
You may override most variables and functions in the build script.

The build scripts are the authoritative record of how to package the 
distribution.  `perl-dist.pl` will never overwrite a build.sh script.
Any tuning or tweaking required may be done in build.sh and may be expected
to be preserved.

## Obtaining a Packaging Building Machine

You must use a machine for packaging either 5.14 or 5.16 modules at a time.  You can switch back and forth, or you can have separate machines.  

The build process will termporarily install IPS dependencies (that is, your modules dependencies will be installed as IPS modules).  So, you'll need sudo on the machine.

You can get Vagrantfiles for both 5.14 and 5.16 from here :  git@trac.omniti.net:/clinton/omnios-packaging-vagrant .

### Making your own build machine

Alternatively, you can do your own install of OmniOS.

You need a release version of OmniOS to use as a build system.  At a minimum, 
you need to do the following to get a basic build environment.

	sudo pkg install developer/gcc46 developer/object-file developer/linker developer/library/lint developer/build/gnu-make system/header system/library/math/header-math

Additionally, you'll need `omniti/runtime/perl` at the desired version and a 
couple of supporting modules.  

If you haven't got the perl.omniti.com publisher configured (see the output of
`pkg publisher`), do:

	sudo pkg set-publisher -g http://pkg.omniti.com/omniti-perl/ perl.omniti.com

Then, something like:

	sudo pkg install omniti/runtime/perl omniti/incorporation/perl-516-incorporation omniti/perl/dist-metadata omniti/perl/json omniti/perl/libwww-perl

will get you Perl 5.16 and the dist packages necessary for the helper script.

### Switching Perl Versions Without Rebuilding The Machine

To change Perl versions, for example going from 5.14 to 5.16:

	$ sudo pkg uninstall $(pkg list -H pkg://perl.omniti.com/* | awk '{ print $1 }')
	$ sudo pkg install omniti/incorporation/perl-516-incorporation omniti/perl/dist-metadata omniti/perl/json omniti/perl/libwww-perl

This will automatically upgrade `omniti/runtime/perl` to the latest release of 
5.16 and install dist packages compatible with 5.16.

You can "downgrade" as well, but it's slightly different, because normally 
`pkg(1)` doesn't want to install an older version. Remove existing perl
incorporation and dist packages as above, then:

	$ sudo pkg update omniti/runtime/perl@5.14

Then install the 5.14 incorporation and supporting dists as above.

### Running a Private Package Repo 

As part of this process, you'll be creating a package which MUST be distrubuted by a repo in order to be installed.

If you prefer to create a repo manually, see http://omnios.omniti.com/wiki.php/CreatingRepos .  It is s simple process.

If you are using the Vagrantfiles, it will automatically create a local repo in /data/set/local-repo, and expose it at http://<vm-hostname>:888/en/catalog.shtml . Its name will be <your-username>.omnios.omniti.com .

To build a package, you must tell the build system where your repo is.  Do this by editing the file 'lib/site.sh' in the build kit checkout:

    # Package server URL and publisher
    #PKGPUBLISHER=omnios-perl
    #PKGSRVR=http://pkg-internal.omniti.com:10008/
    PKGPUBLISHER=clinton.omnios.omniti.com
    PKGSRVR=http://nursery.office.omniti.com:43888/

To test-install your package, you would need to add your local repo.  For example:

     sudo pkg set-publisher -g http://localhost:888/ clinton.omnios.omniti.com
      
You can now 'pkg install foo' to install packages you yourself have made but have not yet been promoted; this may be needed when working on a tree of dependencies.

## Building A New Dist

__Except for package management, all the following build commands are meant to run
as your user, not root.__

### Checkout the Build Kit

In a working space on your build machine, do:

    git clone src@src.omniti.com:~omnios-perl/core/build

The build instructions for each individual CPAN distribution are under build/ .

The main helper script is `./perl-dist.pl`

### Run The Helper Script

You typically use the name of the base module of the distribution as the 
starting point.  If you're not sure, just pick one of the modules and things 
should work out.  Give this module name with the `-m` option to 
`perl-dist.pl`.  It should do the rest, including creating the build 
script (as long as it does not already exist) as well as telling you the order 
in which to build them. For example:

    $ ./perl-dist.pl -m XML::Writer
    Module:       XML::Writer
    Distribution: XML-Writer
    Version:      0.623
    Depends on:
    The following distributions are new:
        XML-Writer


__NOTE:__ The dist script will attempt to determine the license for each 
distribution, but if it can't it will tell you.  You'll need to provide a file 
for pkgmogrify to use to attach a license to the IPS package.  This may be in 
the form of a file such as COPYING or LICENSE in the source tarball, or 
if the code can be distributed under the same terms as Perl itself, you 
can copy a "local.mog" file from an existing dist, e.g.

	cp ../common-sense/local.mog .

where local.mog looks like:

	license perl-artistic-1 license=Artistic
	license perl-gpl-v1 license=GPLv1

These common license files are stored in the repo in the `licenses/` 
subdirectory. The local.mog file lives in the distribution's own build 
directory.

When you've got your list of dists to build, cd into the named subdirectory 
under `build/`.  These directories are named for the dist without the version.  

All you need to do now is run `./build.sh -d <VER>` where `<VER>` is the 
major/minor Perl version, e.g. "5.16".  The build will attempt to install all
necessary build dependencies and will remove any extraneous packages upon
successful completion.

Assuming the build is successful, you will be prompted to confirm that you want
to publish the package (it will say "An error occurred..." but that's just
because we use the same function, `ask_to_continue()`, so don't be concerned.)
In another terminal window, optionally review the IPS manifest that has been
created for the package.  That lives in your build directory, which defaults to
`/tmp/build_<USERNAME>/`.  The manifest will be the IPS package name with
slashes replaced with underscores and with a `.p5m` extension.

	/tmp/build_esproul/omniti_perl_mime-lite.p5m

Reviewing the manifest is optional, and generally things "just work".  If you 
realize after publishing that something was incorrect, just fix the build and 
publish again.  `pkg(1)` clients will always prefer the most recent version that 
is able to be installed.

If a build is not successful, the full output of the run is available in the 
`build.log` file.  If the log file exists when build.sh is run, it is moved to 
`build.log.1` so you always have the current log and one previous.

### Append the Module Name to the Build Order List

__When you've got a working build for your dist, please append the dist name
(which is the same as the directory created by perl-dist.pl) to the
`perl-build-order.txt` file.__

You may review the current list of available dist packages at 
http://pkg.omniti.com/omniti-perl/

### Promoting Your Package to The World

Once you think your build script works well, commit and push your build script
as well as the update(s) to `perl-build-order.txt`.

Assuming you have network access to pkg-il-1.int.omniti.net (check with SRE team if you don't), set:
    PKGPUBLISHER=omnios-perl
    PKGSRVR=http://pkg-il-1.int.omniti.net:10008/
and build against both 5.14 and 5.16 to publish for real.

If you discover a problem with the package later on, just fix it and publish again.  Clients will always prefer the latest version.


### Sample build

        $ pwd
        /home/esproul/git/perl-build
        $ ./perl-dist.pl -m Test::Base
        Module:       Test::Base
        Distribution: Test-Base
        Version:      0.60
        Depends on:   Spiffy
                      Test-Deep


Now we change into the dist's build directory and run build.sh for each version
of Perl we want.  Note that between runs for different Perl versions we'll need
to update `omniti/runtime/perl` and install the matching incorporation package,
which will ensure that build-dep packages are installed at the proper version.

	$ cd build/Test-Base
	$ ./build.sh -d 5.16
	===== Build started at Tue Aug  7 18:41:29 UTC 2012 =====
	Package name: omniti/perl/test-base
	Selected flavor: None (use -f to specify a flavor)
	Selected build arch: both
	Extra dependency: 5.16
	Verifying build dependencies
	--- Build dependency omniti/perl/spiffy not found. Adding it to the list to install.
	--- 1 dependencies are not currently installed.
	--- About to run: sudo pkg install omniti/perl/spiffy
	           Packages to install:  1     
	       Create boot environment: No
	Create backup boot environment: No
	
	DOWNLOAD                                  PKGS       FILES    XFER (MB)
	Completed                                  1/1         8/8      0.0/0.0
	
	PHASE                                        ACTIONS
	Install Phase                                  28/28
	
	PHASE                                          ITEMS
	Package State Update Phase                       1/1 
	Image State Update Phase                         2/2 
	
	PHASE                                          ITEMS
	Reading Existing Index                           8/8 
	Indexing Packages                                1/1
	Testing whether Test::Base is in core
	--- Ensuring omniti/perl/test-base is not installed
	------ Not installed, good.
	--- Module is not in core for Perl 5.16.  Continuing with build.
	Checking for source directory
	--- Source directory not found
	Checking for Test-Base source archive
	--- Archive not found.
	Downloading archive
	Extracting archive: Test-Base-0.60.tar.gz
	Checking for patches in patches/ (in order to apply them)
	--- No series file (list of patches) found
	--- Not applying any patches
	Preparing for build
	--- Creating temporary install dir
	Building 32-bit
	--- make (dist)clean
	--- *** WARNING *** make (dist)clean Failed
	--- Makefile.PL 32-bit
	--- make
	--- make test (i386)
	--- make install (pure)
	Building 64-bit
	--- make (dist)clean
	--- Makefile.PL 64-bit
	--- make
	--- make test ()
	--- make install (pure)
	Making package
	--- Generating package manifest from /tmp/build_esproul/omniti_perl_test-base_pkg
	------ Running: /usr/bin/pkgsend generate /tmp/build_esproul/omniti_perl_test-base_pkg > /tmp/build_esproul/omniti_perl_test-base.p5m.int
	--- Generating package metadata
	------ Setting human-readable version
	------ Adding dependencies
	--- Applying transforms
	--- Publishing package
	Intentional pause: Last chance to sanity-check before publication!

At this point, optionally review `/tmp/build_<USERNAME>/omniti_perl_test-base.p5m`

	An Error occured in the build. Do you wish to continue anyway? (y/n) y
	===== Error occured, user chose to continue anyway. =====
	--- Published omniti/perl/test-base@0.60,5.11-0.151002
	Cleaning up
	--- Removing temporary install directory /tmp/build_esproul/omniti_perl_test-base_pkg
	--- Cleaning up temporary manifest and transform files
	--- Checking to see whether any build dependencies should be removed
	------ Removing: omniti/perl/spiffy 
	------ About to run: sudo pkg uninstall omniti/perl/spiffy 
	            Packages to remove:  1
	       Create boot environment: No
	Create backup boot environment: No
	
	PHASE                                        ACTIONS
	Removal Phase                                  19/19 
	
	PHASE                                          ITEMS
	Package State Update Phase                       1/1 
	Package Cache Update Phase                       1/1
	Image State Update Phase                         2/2
	
	PHASE                                          ITEMS
	Reading Existing Index                           8/8 
	Indexing Packages                                1/1
	Done.


