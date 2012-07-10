package OmniTI::Packaging::MetaCPAN::Module;

use strict;
use warnings;
use base 'OmniTI::Packaging::MetaCPAN';

sub new {
    my $class = shift;
    my %args = @_;
    die "Need a module name" if ( ! $args{'module'} );
    my $self = bless {}, $class;
    $self->lookup( module => $args{'module'} );
    return $self;
}

sub lookup {
    my $self = shift;
    my %args = @_;

    die "Need a module name" if ( ! $args{'module'} );
    return $self->deal_with_fucktards($args{'module'}, 'module') if ( $self->special_snowflakes($args{'module'}, 'module') );

    my $ref = $self->_request( api => 'module', target => $args{'module'} );
    die "[$args{'module'}] Not found" if ( ! $ref || ($ref->{'message'} && $ref->{'message'} =~ /Not found/ ) );

    $self->{'_data'} = $ref;
}

sub author  { my $self = shift; return $self->{'_data'}{'author'}; }
sub summary { my $self = shift; return $self->{'_data'}{'abstract'}; }
sub version { my $self = shift; return $self->{'_data'}{'version'}; }
sub dist    { my $self = shift; return $self->{'_data'}{'distribution'}; }

1;
