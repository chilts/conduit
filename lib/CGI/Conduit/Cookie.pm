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

    # defaults
    $opts ||= {};
    my $expire = $opts->{expire} || '+8hr';

    my $c = CGI::Cookie->new(
        -name    =>  $name,
        -value   =>  $value,
        -expires =>  $expire
    );

    # add this cookie to the response cookie list
    push @{$self->{res_cookie}}, $c;
}

sub cookie_del {
    my ($self, $name) = @_;
    $self->cookie_set($name, '', { expire => '-3d' } );
}

after 'clear' => sub {
    my ($self, $name) = @_;
    delete $self->{cookie};
    delete $self->{res_cookie};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
