## ----------------------------------------------------------------------------

package CGI::Conduit::Cfg;

use Carp;
use Moose::Role;
use Projectus::Cfg qw(cfg_init);

## ----------------------------------------------------------------------------

has 'cfg_obj' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub cfg_load {
    my ($self, $filename) = @_;

    unless ( defined $filename ) {
        croak "No filename provided";
    }

    $self->cfg_obj( cfg_init($filename) );
    return $self->cfg_obj();
}

sub cfg {
    my ($self, $filename) = @_;

    unless ( $self->cfg_obj ) {
        croak "No config file loaded yet, use 'cfg_load' first";
    }

    return $self->cfg_obj;
}

sub cfg_hash {
    my ($self) = @_;
    my %cfg = $self->cfg_obj->vars();
    return \%cfg;
}

sub cfg_value {
    my ($self, $key) = @_;
    return $self->cfg_obj->param($key);
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
