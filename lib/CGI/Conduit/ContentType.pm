## ----------------------------------------------------------------------------

package CGI::Conduit::ContentType;

use Moose::Role;
use JSON::Any;

## ----------------------------------------------------------------------------

sub render_json {
    my ($self, $data) = @_;

    $self->res_content_type('application/json; charset=utf-8');
    $self->res_content( JSON::Any->objToJson( $data ) );
    $self->render_final();
}

sub render_text {
    my ($self, $text) = @_;

    $self->res_content_type('text/plain; charset=utf-8');
    $self->res_content( $text );
    $self->render_final();
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
