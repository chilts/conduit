## ----------------------------------------------------------------------------

package CGI::Conduit::Redis;

use Moose::Role;

use Redis;

## ----------------------------------------------------------------------------

sub redis {
    my ($self) = @_;

    return $self->{redis} if $self->{redis};

    # currently we have no redis object, so let's create it
    my $server = $self->cfg_value( q{redis_server} );

    die 'No redis server specified'
        unless $server;

    $self->{redis} = Redis->new({
        server => $server,
    });

    return $self->{redis};
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
