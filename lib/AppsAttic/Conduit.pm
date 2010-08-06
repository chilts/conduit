## ----------------------------------------------------------------------------

package AppsAttic::Conduit;

use strict;
use warnings;
use base 'CGI::Conduit';

## ----------------------------------------------------------------------------

sub setup_handlers {
    my ($self) = @_;
    $self->add_handler( qr{ \A / \z }xms, 'home' );

    # do a path based on a HASH
    $self->add_handler( { '/api/' => 1, '/blog/' => 1, }, 'dunno' );

    # the path based on an ARRAY (in this case, coming from the config)
    my @sections = $self->cfg_value('sections');
    $self->add_handler( \@sections, 'section_redirect' );

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

    $self->stash_set('title', 'Whassssuuuupppppp<>!');
    $self->render_template( q{item-news.html} );
}

sub section_redirect {
    my ($self) = @_;

    $self->http_moved_permanently( $self->req_path . '/' );
}

sub dunno {
    my ($self) = @_;
    $self->stash_set('title', 'Dunno what this is');
    $self->render_template( q{item-blog-entry.html} );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
