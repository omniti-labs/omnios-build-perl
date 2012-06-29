package OmniTI::Packaging::MetaCPAN;

use strict;
use warnings;
use JSON;

our $URL = "http://api.metacpan.org";

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub _request {
    my $self = shift;
    my %args = @_;

    die "api and target required" if ( ! $args{'api'} || ! $args{'target'} );

    my $json = `curl -s $URL/$args{'api'}/$args{'target'}`;
    my $ref = decode_json($json);
    return $ref;
}

sub special_snowflakes {
    my $self = shift;
    my $target = shift;
    my $type = shift;

    if ( $type eq 'module' ) {
        foreach (qw(common::sense)) {
            return 1 if ( $target eq $_ );
        }
    }
    elsif ( $type eq 'dist' ) {
        foreach (qw(common-sense)) {
            return 1 if ( $target eq $_ );
        }
    }
}

sub deal_with_fucktards {
    my $self = shift;
    my $target = shift;
    my $type = shift;

    if ( $type eq 'module' ) {
        if ( $target eq 'common::sense' ) {
            $self->{'_data'} = {
                author              => 'MLEHMANN',
                abstract            => 'save a tree AND a kitten, use common::sense!',
                version_numified    => 3.6,
                distribution        => 'common-sense'
            };
        }
    }
    elsif ( $type eq 'dist' ) {
        if ( $target eq 'common-sense' ) {
            $self->{'_data'} = {
                license     => ['perl_5'],
                dependency  => []
            };
        }
    }
}

1;
