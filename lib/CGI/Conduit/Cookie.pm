## ----------------------------------------------------------------------------

package CGI::Conduit::Cookie;

use Moose::Role;

use CGI::Cookie;

## ----------------------------------------------------------------------------

has 'res_cookie' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub cookie {
    my ($self) = @_;

    return $self->{cookie} if $self->{cookie};

    # get them from CGI::Cookie
    my %cookies = CGI::Cookie->fetch();
    $self->{cookie} = \%cookies;
    return $self->{cookie};
}

sub cookie_get {
    my ($self, $name) = @_;
    return $self->cookie->{$name};
}

sub cookie_set {
    my ($self, $name, $value, $opts) = @_;
    $opts ||= {};

    my %args = (
        -name    =>  $name,
        -value   =>  $value,
    );

    # if we have been given an expiration, set it
    if ( $opts->{expires} ) {
        $args{expires} = $opts->{expires};
    }

    my $c = CGI::Cookie->new( %args );

    # add this cookie to the response cookie list
    push @{$self->{res_cookie}}, $c;
}

sub cookie_del {
    my ($self, $name) = @_;
    $self->cookie_set($name, '', { expires => '-3d' } );
}

after 'clear' => sub {
    my ($self, $name) = @_;
    delete $self->{cookie};
    delete $self->{res_cookie};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
