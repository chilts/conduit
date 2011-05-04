## ----------------------------------------------------------------------------

package CGI::Conduit::Session;

use Carp qw(croak);
use String::Random::NiceURL qw(id);

use Moose::Role;

with 'CGI::Conduit::Memcache';
with 'CGI::Conduit::Cookie';
with 'CGI::Conduit::Log';

use Log::Log4perl qw(get_logger);

my $log = get_logger();

## ----------------------------------------------------------------------------

has 'session_id' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub session {
    my ($self) = @_;

    # if we already have the session, return it
    return $self->{session} if $self->{session};

    # firstly, check for a session cookie
    my $cookie = $self->cookie_get('session');
    return unless defined $cookie;

    # get the cookie value which is the session id and check it for validity
    my $id = $cookie->value();
    unless ( $self->is_session_id_valid($id) ) {
        $log->warn(qq{session(): session id '$id' invalid});
        $self->cookie_del( q{session} );
        return;
    }

    # retrieve the session
    my $session = $self->session_get( $id );
    unless ( defined $session ) {
        $log->warn(qq{session(): session id '$id' doesn't exist});
        $self->cookie_del( q{session} );
        return;
    }

    $log->debug(qq{session(): found session id '$id'});

    # remember the session and it's id
    $self->session_id( $id );
    $self->{session} = $session;

    # return the session
    return $session;
}

sub is_session_id_valid {
    my ($self, $id) = @_;
    return 1 if $id =~ m{ \A [A-Za-z0-9-_]{32} \z }xms;
    return;
}

# Note: if make a session twice, the second Cookie will override the first and
# the first session will be inaccessible
sub session_new {
    my ($self, $value) = @_;

    unless ( $value ) {
        $log->fatal(qq{Trying to set a session to undef});
        croak qq{Trying to set a session to undef};
    }

    my $id = id(32);
    my $mc = $self->memcache();
    unless ( $mc->set("session:$id", $value) ) {
        $log->warn("session_new(): Trying to set new session '$id' failed");
        return;
    }

    $log->debug("session_new(): Setting new session '$id'");

    # saving the session worked, so set the appropriate bits and return the id
    my $opts = {};
    if ( $self->cfg_value('session_expire') ) {
        $opts->{expire} = $self->cfg_value('session_expire');
    }
    $self->cookie_set( q{session}, $id, $opts );
    $self->session_id($id);
    $self->{session} = $value;
    return $id;
}

sub session_set {
    my ($self, $value) = @_;

    unless ( $self->session ) {
        $log->fatal(qq{Trying to set a session that doesn't yet exist});
        croak qq{Trying to set a session that doesn't yet exist};
    }

    # must be there if $self->session() succeeded
    my $id = $self->session_id();

    unless ( $value ) {
        $log->fatal(qq{Trying to set a session to undef});
        croak qq{Trying to set a session to undef};
    }

    my $mc = $self->memcache();
    unless ( $mc->set("session:$id", $value) ) {
        $log->warn("session_set(): Trying to set session '$id' failed");
        return;
    }

    # remember this new session
    $self->{session} = $value;
}

sub session_get {
    my ($self, $id) = @_;

    # just return the session if it's there
    return $self->memcache()->get( qq{session:$id} );
}

sub session_del {
    my ($self) = @_;

    unless ( $self->session ) {
        $log->fatal("session_del(): trying to delete a session which doesn't (yet) exist");
        croak "session_del(): trying to delete a session which doesn't (yet) exist";
    }

    my $id = $self->session_id();

    # remove from memcache, set a cookie and clear what we have
    $self->memcache->delete( qq{session:$id} );
    $self->cookie_del( q{session} );
    delete $self->cookie->{session};
    $self->session_clear();
}

sub session_clear {
    my ($self) = @_;
    delete $self->{session};
    delete $self->{session_id};
}

after 'clear' => sub {
    my ($self) = @_;
    delete $self->{session};
    delete $self->{session_id};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
