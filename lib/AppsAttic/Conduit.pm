## ----------------------------------------------------------------------------

package AppsAttic::Conduit;

use Moose;

extends 'CGI::Conduit';

with qw(
    CGI::Conduit::Cookie
    CGI::Conduit::Session
    CGI::Conduit::Memcache
    CGI::Conduit::Log
    CGI::Conduit::Template
);

use Log::Log4perl qw(get_logger);

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
    $self->add_handler( '/cookie', 'page_cookie' );
    $self->add_handler( '/cookie/del', 'page_cookie_del' );
    $self->add_handler( '/session', 'page_session' );
    $self->add_handler( '/session/new', 'page_session_new' );
    $self->add_handler( '/session/invalid', 'page_session_set_invalid' );
    $self->add_handler( '/session/unknown', 'page_session_set_unknown' );
    $self->add_handler( '/session/del', 'page_session_del' );
    $self->add_handler( '/log', 'page_log' );
    $self->add_handler( '/cgi', 'page_cgi' );
    $self->add_handler( '/header', 'page_header' );

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
    $self->tt_stash_set('title', 'Debug');
    $self->render_template( q{debug.html}, { conduit => $self } );
}

sub home {
    my ($self) = @_;

    $self->tt_stash_set('title', 'Whassssuuuupppppp<>!');
    $self->render_template( q{item-news.html} );
}

sub section_redirect {
    my ($self) = @_;

    $self->status_moved_permanently( $self->req_path . '/' );
}

sub blog_entry {
    my ($self) = @_;
    $self->tt_stash_set('title', 'Dunno what this is');
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

    # now render the template
    $self->tt_stash_set('title', 'Memcache information');
    $self->render_template( q{memcache.html} );
}

sub page_cookie {
    my ($self) = @_;

    # read a cookie
    my $cookie = $self->cookie();
    if ( exists $cookie->{count} ) {
        my $c = $cookie->{count};

        # if we reach 10, delete the cookie completely
        if ( $c->value >= 10 ) {
            $self->cookie_del( q{count} );

            # we now have a 'success'
            $self->cookie_set( q{success} , 'Is Mine!' );
        }
        else {
            # carry on incrementing the cookie
            $self->cookie_set( q{count} , $c->value + 1 );
            $self->cookie_del( q{success} )
                if $c->value == 5;
        }
    }
    else {
        # create a new cookie with count as one
        $self->cookie_set( q{count}, 1 );
    }

    # now render the template
    $self->tt_stash_set('title', 'Cookie Information');
    $self->render_template( q{cookie.html} );
}

sub page_cookie_del {
    my ($self) = @_;

    my $name = $self->req_param('name');
    warn "name=$name";

    unless ( defined $name ) {
        $self->tt_stash_set( 'err', 'No cookie name provided' );
        $self->render_template( q{cookie.html} );
        return;
    }

    # read the cookie
    my $cookie = $self->cookie_get($name);
    if ( defined $cookie ) {
        # cookie does exist, so delete it
        $self->cookie_del( $name );
        $self->tt_stash_set( 'msg', qq{Cookie '$name' deleted} );
    }
    else {
        # no cookie
        $self->tt_stash_set( 'err', qq{Cookie '$name' doesn't exist} );
    }

    # now render the template
    $self->tt_stash_set('title', 'Cookie Information');
    $self->render_template( q{cookie.html} );
}

sub page_cgi {
    my ($self) = @_;

    # now render the template
    $self->tt_stash_set('title', 'CGI Info');
    $self->render_template( q{cgi.html} );
}

sub page_header {
    my ($self) = @_;

    $self->hdr_no_cache();

    # now render the template
    $self->tt_stash_set('title', 'Header - no cache');
    $self->render_template( q{header.html} );
}

sub page_session {
    my ($self) = @_;

    # now render the template
    $self->tt_stash_set('title', 'Sessional');
    $self->tt_stash_set('session', $self->session);
    $self->render_template( q{session.html} );
}

sub page_session_new {
    my ($self) = @_;

    # set a new session unless we already have one
    my $msg;
    if ( $self->session ) {
        $msg = q{Session already exists, not written over};
    }
    else {
        $self->session_new( { username => 'andy', admin => 1 } );
        $msg = q{New session created};
    }

    # now render the template
    $self->tt_stash_set('title', 'Sessional');
    $self->tt_stash_set('msg', $msg);
    $self->tt_stash_set('session', $self->session);
    $self->render_template( q{session.html} );
}

sub page_session_del {
    my ($self) = @_;

    # firstly, see if we have a session
    my $msg;
    if ( $self->session ) {
        $msg = q{Session deleted};
        $self->session_del();
    }
    else {
        $msg = q{No session to delete};
    }

    # now render the template
    $self->tt_stash_set('title', 'Sessional');
    $self->tt_stash_set('msg', $msg);
    $self->tt_stash_set('session', $self->session);
    $self->render_template( q{session.html} );
}

sub page_session_set_invalid {
    my ($self) = @_;

    $self->cookie_set( q{session}, '^*&@{}":;,./<>?');

    # now render the template
    $self->tt_stash_set('title', 'Sessional');
    $self->tt_stash_set('msg', 'Invalid session set');
    $self->render_template( q{session.html} );
}

sub page_session_set_unknown {
    my ($self) = @_;

    $self->cookie_set( q{session}, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

    # now render the template
    $self->tt_stash_set('title', 'Sessional');
    $self->tt_stash_set('msg', 'Valid session id, but unknown session set');
    $self->render_template( q{session.html} );
}

sub page_log {
    my ($self) = @_;

    my $msg = $self->req_param('msg');

    my $log = get_logger();
    $log->info(qq{Someone said: $msg});

    $self->tt_stash_set('title', 'Log Stuff');
    $self->tt_stash_set('msg', qq{You just logged: $msg});
    $self->render_template( q{log.html} );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
