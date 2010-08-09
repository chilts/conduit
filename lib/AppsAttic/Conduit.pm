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
    $self->add_handler( { '/blog/' => 1, }, 'blog_entry' );
    $self->add_handler( { '/api/' => 1, }, 'home' );

    # the path based on an ARRAY (in this case, coming from the config)
    my @sections = $self->cfg_value('sections');
    $self->add_handler( \@sections, 'section_redirect' );

    # let's check against a string for debug pages
    $self->add_handler( '/debug', 'debug' );
    $self->add_handler( '/memcache', 'page_memcache' );

    return;

    # ToDo: make it look like this
    $self->add_handler({
        match         => qr{ \A / \z }xms,
        method        => 'home',
        # authenticated => 0,
        # admin         => 0,
    });
}

sub debug {
    my ($self) = @_;
    $self->stash_set('title', 'Debug');
    $self->render_template( q{debug.html}, { conduit => $self } );
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

sub blog_entry {
    my ($self) = @_;
    $self->stash_set('title', 'Dunno what this is');
    $self->render_template( q{item-blog-entry.html} );
}

sub page_memcache {
    my ($self) = @_;

    # increment count (or set it if not yet set)
    if ( !$self->memcache->incr('count') ) {
        # couldn't increment so add it (don't use set since someone else might have done it already)
        if ( !$self->memcache->add('count', 1) ) {
            # add failed, so someone else did it already, so just try incr again
            $self->memcache->incr('count')
        }
    }
    warn 'count=', $self->memcache->get('count');

    # now render the template
    $self->stash_set('title', 'Memcache information');
    $self->render_template( q{memcache.html} );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
