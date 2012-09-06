package OmniTI::Package;

use strict;
use warnings;

use Data::Dumper;
use Dist::Metadata;
use File::Path qw( make_path );
use JSON;
use LWP::Simple;
use Module::CoreList;

our $VERSION = 0.01;

sub new {
    my ($class, %opts) = @_;

    my $self = {};

    $self->{'_get_deps'} = $opts{'deps'} || 0;

    $self->{'_build_deps'} = [];
    $self->{'_run_deps'} = [];

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
                    foreach my $mod (keys %{$metadata->{'prereqs'}->{$deptype}->{$req}}) {
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

sub provides {
    my ($self) = @_;

    return @{$self->{'_provides'}};
}

sub generate_build {
    my ($self, $rootdir) = @_;

    die "No base directory for build scripts provided!" unless $rootdir;
    die "Invalid base directory for build scripts: $rootdir" unless -d $rootdir;

    my $build_dir = $rootdir . '/build/' . $self->dist;
    $build_dir =~ s{/+}{/}g;

    return if -f "$build_dir/build.sh";

    
}

sub add_dep {
    # Adds dependencies to the current package recursively. Each dependency will
    # itself be a full OmniTI::Package object. Skips any CORE dependencies.
    # Dependencies can be assured to be in the correct order for building since
    # we populate the deplist depth-first.
    my ($self, $list, $name, $recurse) = @_;

    $recurse = 0 unless $recurse;

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
        : OmniTI::Package->new( module => $name, cache => $self->{'_mod_cache'}, deps => $recurse );

    $self->{'_mod_cache'}->{$name} = $dep unless $self->{'_mod_cache'}->{$name};
    $self->{'_mod_cache'}->{$dep->module()} = $dep unless $self->{'_mod_cache'}->{$dep->module()};
    $self->{'_mod_cache'}->{$_} = $dep for $dep->provides();

    if ($list eq 'build' && $recurse) {
        my %seen;

        my @t = @{$self->{'_build_deps'}};
        $self->{'_build_deps'} = [];

        foreach my $d ((@t, $dep->builddeps)) {
            next if $seen{$d->module};
            $seen{$d->module} = 1;
            push(@{$self->{'_build_deps'}}, $d);
        }
    }
    push(@{$self->{'_build_deps'}}, $dep) if $list eq 'build';

    if ($list eq 'run' && $recurse) {
        my %seen;

        my @t = @{$self->{'_run_deps'}};
        $self->{'_run_deps'} = [];

        foreach my $d ((@t, $dep->rundeps)) {
            next if $seen{$d->module};
            $seen{$d->module} = 1;
            push(@{$self->{'_run_deps'}}, $d);
        }
    }
    push(@{$self->{'_run_deps'}}, $dep) if $list eq 'run';
}

sub _temp_dir {
    my ($dist) = @_;

    die "No distribution name provided!" unless $dist;

    my $dir = '/tmp/build_' . getpwuid($<) . "/$dist";
    make_path($dir);

    return $dir;
}

1;
