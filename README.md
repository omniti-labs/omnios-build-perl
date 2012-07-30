# Packaging Perl Distributions for OmniOS

We deliver Perl module distributions as IPS packages and make them available via 
the __perl.omniti.com__ publisher.

For a more detailed explanation of IPS packaging, please see the [IPS Dev 
 Guide](http://hub.opensolaris.org/bin/download/Project+pkg/files/ipsdevguide.pdf), 
 particularly Chapter 3, which will explain the terminology.

## How This Repository is Structured

The Perl build repo is laid out like other OmniOS build repos, with some 
additional code to facilitate metadata processing, particularly dependency 
resolution.  In the root directory, `perl_module_dist.pl` is used to make new 
build scripts.  The build scripts themselves live in the "build" subdirectory.

The bulk of the build work is done via two shell files in lib, config.sh and 
functions.sh.  You should not need to change anything directly in these files.  
You may override most variables in the build script.

## Building A New Dist

You need a release version of OmniOS to use as a build system.  At a minimum, 
you need to do the following to get a basic build environment.

	sudo pkg install developer/gcc46 developer/object-file developer/linker developer/library/lint developer/build/gnu-make system/header system/library/math/header-math

You typically use the name of the base module of the distribution as the 
starting point.  If you're not sure, just pick one of the modules and things 
should work out.  Give this module name with the `-m` option to 
`perl_module_dist.pl`.  It should do the rest, including creating the build 
script (as long as it does not already exist) as well as telling you the order 
in which to build them. For example:

	./perl_module_dist.pl -m MIME::Lite
	Installation order:
	Email-Date-Format
	MIME-Lite

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
View the build.sh script and check the `BUILD_DEPENDS_IPS` variable.  Ensure 
these packages are installed.  The first three packages are always present:

	developer/build/gnu-make system/header system/library/math/header-math

Any additional packages specified are requirements to build this distribution.  
The simplest way to get them is to copy the entire set of packages in that 
variable line and `sudo pkg install` them.  Don't worry if some packages are 
already installed, as pkg will skip them.

All you need to do now is run `./build.sh -d <VER>` where `<VER>` is the 
major/minor Perl version, e.g. "5.16".  Assuming the build is successful, you 
will be prompted to confirm that you want to publish the package (it will say 
"An error occurred..." but that's just because we use the same function, 
`ask_to_continue()`, so don't be concerned.)  In another terminal window, feel 
free to review the IPS manifest that has been created for the package.  That 
lives in your build directory, which defaults to `/tmp/build_<username>/`.  The 
manifest will be the IPS package name with slashes replaced with underscores and 
with a `.p5m` extension.

	/tmp/build_esproul/omniti_perl_mime-lite.p5m

Reviewing the manifest is optional, and generally things "just work".  If you 
realize after publishing that something was incorrect, just fix the build and 
publish again.  `pkg(1)` clients will always prefer the most recent version that 
is able to be installed.

If a build is not successful, the full output of the run is available in the 
`build.log` file.  If the log file exists when build.sh is run, it is moved to 
`build.log.1` so you always have the current log and one previous.

You may review the current list of available dist packages at 
http://pkg.omniti.com/omniti-perl/
