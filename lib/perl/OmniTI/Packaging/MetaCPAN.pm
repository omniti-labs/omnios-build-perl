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
        foreach (qw(common::sense DBIx::Safe Devel::Leak)) {
            return 1 if ( $target eq $_ );
        }
    }
    elsif ( $type eq 'dist' ) {
        foreach (qw(common-sense DBIx-Safe Devel-Leak)) {
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
                version             => 3.6,
                distribution        => 'common-sense'
            };
        }
        if ( $target eq 'DBIx::Safe' ) {
            $self->{'_data'} = {
                author              => 'TURNSTEP',
                abstract            => 'Safer access to your database through a DBI database handle',
                version             => 1.2.5,
                distribution        => 'DBIx-Safe'
            };
        }
        if ( $target eq 'Devel::Leak' ) {
            $self->{'_data'} = {
                author              => 'NI-S',
                abstract            => 'Utility for looking for perl objects that are not reclaimed.',
                version             => 0.03,
                distribution        => 'Devel-Leak'
            };
        }
    }
    elsif ( $type eq 'dist' ) {
        if ( $target eq 'common-sense' || $target eq 'Devel-Leak' ) {
            $self->{'_data'} = {
                license     => ['perl_5'],
                dependency  => []
            };
        }
    }
}

1;
