## ----------------------------------------------------------------------------

package CGI::Conduit::Memcache;

use Moose::Role;

use Cache::Memcached;

## ----------------------------------------------------------------------------

sub memcache {
    my ($self) = @_;

    return $self->{memcache} if $self->{memcache};

    # currently we have no memcache object, so let's create it
    my @servers = $self->cfg_value( q{memcache_servers} );
    my $ns = $self->cfg_value( q{memcache_namespace} );

    die 'No memcache servers specified'
        unless @servers;

    $self->{memcache} = Cache::Memcached->new({
        'servers'   => \@servers,
        'namespace' => $ns // '',
    });

    return $self->{memcache};
}

# sub memcache_incr (so we don't have to write the weird stuff all the time)

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
