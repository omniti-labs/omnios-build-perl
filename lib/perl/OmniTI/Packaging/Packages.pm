package OmniTI::Packaging::Packages;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_prime();
    return $self;
}

sub is_installed {
    my $self = shift;
    my %args = @_;
    die "need dist" if ( ! $args{'dist'} );
    return 1 if ( $self->{'_installed'}{lc $args{'dist'}} );
    return 0;
}

sub is_perlcore {
    my $self = shift;
    my %args = @_;
    die "need module" if ( ! $args{'module'} );
    die "need dist" if ( ! $args{'dist'} );
    return 0 if ( $self->is_installed(%args) );

    `$^X -M$args{'module'} -e "1;" > /dev/null 2>&1`;
    if ($? == -1 || $? & 127 || $? >> 8 != 0) {
        return 0;
    }
    return 1;
}

sub add_installed {
    my $self = shift;
    my %args = @_;
    die "need dist" if ( ! $args{'dist'} );
    $self->{'_installed'}{lc $args{'dist'}};
}

sub _prime {
    my $self = shift;
    my $installed = `pkg list | grep omniti/perl/`;
    while ( $installed =~ /omniti\/perl\/([^\s]+)/g ) {
        $self->{'_installed'}{lc $1} = 1;
    }
}

1;
