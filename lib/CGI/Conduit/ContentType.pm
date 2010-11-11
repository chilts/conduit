## ----------------------------------------------------------------------------

package CGI::Conduit::ContentType;

use Moose::Role;
use JSON::Any;

## ----------------------------------------------------------------------------

sub render_json {
    my ($self, $data) = @_;

    $self->render_content_with_type(
        'application/json; charset=utf-8',
        JSON::Any->objToJson( $data ),
    );
}

sub render_text {
    my ($self, $text) = @_;

    $self->render_content_with_type(
        'text/plain; charset=utf-8',
        $text,
    );
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
