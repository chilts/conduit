## ----------------------------------------------------------------------------

package CGI::Conduit::Session;

use Carp qw(croak);
use String::Random::NiceURL qw(id);

use Moose::Role;

with 'CGI::Conduit::Memcache';
with 'CGI::Conduit::Cookie';
with 'CGI::Conduit::Log';

use Log::Log4perl qw(get_logger);

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

    my $log = get_logger();

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

sub session_new {
    my ($self, $value) = @_;

    unless ( $value ) {
        my $log = get_logger();
        $log->fatal(qq{Trying to set a session to undef});
        croak qq{Trying to set a session to undef};
    }

    my $log = get_logger();

    my $id = id(32);
    my $mc = $self->memcache();
    unless ( $mc->set("session:$id", $value) ) {
        $log->warn("session_new(): Trying to set session $id failed");
        return;
    }

    $log->debug("session_new(): Setting new session '$id'");

    # setting the session worked, so set the appropriate bits and return the id
    $self->cookie_set( q{session}, $id );
    $self->session_id($id);
    $self->{session} = $value;
    return $id;
}

sub session_set {
    my ($self, $id, $value) = @_;

    unless ( $value ) {
        my $log = get_logger();
        $log->fatal(qq{Trying to set a session to undef});
        croak qq{Trying to set a session to undef};
    }

    my $mc = $self->memcache();
    $mc->set("session:$id", $value);
}

sub session_get {
    my ($self, $id) = @_;

    # no need to check for a valid session id since that's already been done,
    # so just return the session if it's there
    return $self->memcache()->get( qq{session:$id} );
}

sub session_del {
    my ($self) = @_;

    unless ( $self->session ) {
        my $log = get_logger();
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
