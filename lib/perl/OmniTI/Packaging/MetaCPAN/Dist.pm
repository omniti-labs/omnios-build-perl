package OmniTI::Packaging::MetaCPAN::Dist;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use base 'OmniTI::Packaging::MetaCPAN';

# A lot of commonly used things will be unknown, instead of fixing them manually each time
# do so once here
our %licenses = (
    'JSON-XS'   => ['perl_5']
);

sub new {
    my $class = shift;
    my %args = @_;
    die "Need a dist name" if ( ! $args{'dist'} );
    my $self = bless {}, $class;
    $self->lookup( dist => $args{'dist'} );
    return $self;
}

sub lookup {
    my $self = shift;
    my %args = @_;

    die "Need a dist name" if ( ! $args{'dist'} );
    return $self->deal_with_fucktards($args{'dist'}, 'dist') if ( $self->special_snowflakes($args{'dist'}, 'dist') );

    my $ref = $self->_request( api => 'release', target => $args{'dist'} );
    die "Not found" if ( ! $ref || ($ref->{'message'} && $ref->{'message'} =~ /Not found/ ) );

    if ( (! scalar(@{$ref->{'license'}}) || $ref->{'license'}[0] eq 'unknown') && $licenses{$args{'dist'}} ) {
        $ref->{'license'} = $licenses{$args{'dist'}};
    }

    $self->{'_data'} = $ref;
    return $ref;
}

sub license_for_mog {
    my $self = shift;

    my $mog;
    foreach my $l ( @{$self->{'_data'}{'license'}} ) {
        die "unknown" if ( $l eq 'unknown' );
        if ( $l eq 'perl_5' ) {
            $mog .= "license perl-artistic-1 license=Artistic\n";
            $mog .= "license perl-gpl-v1 license=GPLv1\n";
        }
    }
    return $mog;
}

sub deps {
    my $self = shift;
    my %args = @_;

    if ( ! $args{'module_cache'} ) {
        die "You should really pass module_cache (cache of OmniTI::Packaging::MetaCPAN::Module objects";
    }
    if ( ! $args{'pkg_obj'} || ! blessed $args{'pkg_obj'} || ! $args{'pkg_obj'}->isa("OmniTI::Packaging::Packages") ) {
        die "Need OmniTI::Packaging::Packages passed as pkg_obj";
    }

    my @deps;
    foreach my $dep ( @{$self->{'_data'}{'dependency'}} ) {
        next if $dep->{'module'} eq 'perl';
        next if $dep->{'relationship'} eq 'recommends';

        $args{'module_cache'}{$dep->{'module'}} = OmniTI::Packaging::MetaCPAN::Module->new( module => $dep->{'module'} );
        if ( ! $args{'pkg_obj'}->is_perlcore( module => $dep->{'module'}, dist => $args{'module_cache'}{$dep->{'module'}}->dist() ) ) {
            push @deps, {
                module  => $dep->{'module'},
                dist    => $args{'module_cache'}{$dep->{'module'}}->dist()
            };
        }
    }

    return \@deps;
}

1;
