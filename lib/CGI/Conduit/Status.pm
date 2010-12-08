## ----------------------------------------------------------------------------

package CGI::Conduit::Status;

use Moose::Role;

## ----------------------------------------------------------------------------

has 'status' => ( is => 'rw' );

## ----------------------------------------------------------------------------

# no need for 'sub status', since the above declaration takes care of it

## ----------------------------------------------------------------------------
# easy canned responses

sub status_temp_redirect {
    my ($self, $url) = @_;
    print $self->cgi->redirect(
        -uri    => $url,
        -status => 302,
        -cookie => $self->res_cookie,
    );
}

sub status_moved_permanently {
    my ($self, $url) = @_;
    print $self->cgi->redirect(
        -uri    => $url,
        -status => 301,
        -cookie => $self->res_cookie,
    );
}

sub status_not_found {
    my ($self) = @_;
    $self->status(404);
    $self->render_template( q{404.html} );
}

sub status_forbidden {
    my ($self) = @_;
    $self->status(403);
    $self->render_template( q{403.html} );
}

sub status_internal_server_error {
    my ($self) = @_;
    $self->status(500);
    $self->render_template( q{500.html} );
}

after 'clear' => sub {
    my ($self) = @_;
    delete $self->{status};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
