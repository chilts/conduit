## ----------------------------------------------------------------------------

package CGI::Conduit::Cfg;

use Moose::Role;

use Config::Simple;

## ----------------------------------------------------------------------------

has 'cfg_obj' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub cfg {
    my ($self, $filename) = @_;

    if ( defined $filename ) {
        $self->cfg_obj( Config::Simple->new( $filename ) );
    }

    return $self->cfg_obj;
}

#sub cfg_load {
#    my ($self, $filename) = @_;
#    $self->cfg_obj( Config::Simple->new( $filename ) );
#}

sub cfg_value {
    my ($self, $key) = @_;
    return $self->cfg_obj->param($key);
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
