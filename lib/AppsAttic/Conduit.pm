## ----------------------------------------------------------------------------

package AppsAttic::Conduit;

use strict;
use warnings;
use base 'CGI::Conduit';

## ----------------------------------------------------------------------------

sub setup_handlers {
    my ($self) = @_;
    $self->add_handler( qr{ \A / \z }xms, 'home' );

    return;

    # ToDo: make it look like this
    $self->add_handler({
        match         => qr{ \A / \z }xms,
        method        => 'home',
        # authenticated => 0,
        # admin         => 0,
    });
}

sub home {
    my ($self) = @_;

    #print "Content-type: text/html\n\n";
    #print "Hello, World!\n";

    # $self->res_content_type( q{text/plain; charset=utf-8} );
    # $self->res_content( qq{Hello, World!\n} );
    # $self->render_content();

    $self->render_template( q{item-news.html} );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
