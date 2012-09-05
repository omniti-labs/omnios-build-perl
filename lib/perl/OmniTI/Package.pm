package OmniTI::Package;

use Data::Dumper;
use Dist::Metadata;
use File::Path qw( make_path );
use JSON;
use LWP::Simple;
use Module::CoreList;

our $VERSION = 0.01;

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;

    if ($opts{'module'}) {
        $self->module($opts{'module'});
    } elsif ($opts{'dist'}) {
        $self->dist($opts{'dist'});
    } elsif ($opts{'archive'}) {
        $self->archive($opts{'archive'});
    }

    $self->{'_build_deps'} = [];
    $self->{'_run_deps'} = [];

    return $self;
}

sub builddeps {
    my ($self) = @_;
}

sub rundeps {
    my ($self) = @_;
}

sub module {
    my ($self, $module) = @_;

    return $self->{'_module'} if $self->{'_module'};

    my $res = get('http://search.cpan.org/api/module/' . $module) || die "Error contacting CPAN!";
    my $json = decode_json($res) || die "Bad response from CPAN!";

    die "CPAN error for $module: $json->{'error'}\n" if $json->{'error'};
    die "No distribution name found for $module!" unless $json->{'distvname'};

    $self->dist($json->{'distvname'});

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

    getstore($url, $file);

    die "Error downloading archive for $dist" unless -f $file;

    $self->archive($file);

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
        $self->{'_module'} = (sort { length($a) <=> length($b) } keys %{$metadata->{'provides'}})[0];
        $self->{'_version'} = $metadata->{'version'};
        $self->{'_author'} = ($metadata->{'x_authority'} =~ m{cpan:(.*)})[0] || 'UNKNOWN';
        $self->{'_summary'} = $metadata->{'abstract'};
        $self->{'_original_summary'} = $metadata->{'abstract'};

        foreach my $deptype (keys %{$metadata->{'prereqs'}}) {
            foreach my $req (keys %{$metadata->{'prereqs'}->{$deptype}}) {
                foreach my $mod (keys %{$metadata->{'prereqs'}->{$deptype}->{$req}}) {
                    $self->add_dep('build', 'module', $mod);
                    $self->add_dep('run', 'module', $mod) if $deptype eq 'runtime';
                }
            }
        }
    }

    return $self->{'_archive'};
}

sub summary {
    my ($self, $summary) = @_;

    $self->{'_summary'} = $summary if defined $summary;
    $self->{'_summary'} = $self->{'_original_summary'}
        if $self->{'_original_summary'} && defined $summary && !$summary;

    return $self->{'_summary'} || '(No summary available on CPAN)'
}

sub generate_build {
    my ($self, $rootdir) = @_;
}

sub add_dep {
    # Adds dependencies to the current package recursively. Each dependency will
    # itself be a full OmniTI::Package object. Skips any CORE dependencies.
    # Dependencies can be assured to be in the correct order for building since
    # we populate the deplist depth-first.
    my ($self, $list, $type, $name) = @_;

    return if $name eq 'perl';

    die "Invalid dependency type provided (must be 'module' or 'dist')!"
        unless $type eq 'module' || $type eq 'dist';

    # short circuit if the dependency is already in the list
    return if $type eq 'module' && grep { $_->module() eq $name } @{$deplist};
    return if $type eq 'dist' && grep { $_->dist() eq $name } @{$deplist};

    # new dependency, so now the descent begins and we create a new object for it
    # which will trigger it to fill in its own dependencies, and so on, until there
    # is nothing in the list but CORE modules
    my $dep = OmniTI::Package->new();
    $dep->module($name) if $type eq 'module';
    $dep->dist($name) if $type eq 'dist';

    # skip adding to the deplist if this one's a CORE module
    return if Module::CoreList::find_modules($dep->module);

    push(@{$self->{'_build_deps'}}, $dep->build_deps) if $list eq 'build';
    push(@{$self->{'_run_deps'}}, $dep->run_deps) if $list eq 'run';
}

sub _temp_dir {
    my ($dist) = @_;

    die "No distribution name provided!" unless $dist;

    my $dir = '/tmp/build_' . getpwuid($<) . "/$dist/";
    make_path($dir);

    return $dir;
}

1;
