## ----------------------------------------------------------------------------

package CGI::Conduit::Valid;
use Moose::Role;

use Projectus::Valid; # export nothing, we'll be explicit here

## ----------------------------------------------------------------------------

sub valid_something {
    my ($self, $something) = @_;
    return Projectus::Valid::valid_something( $something );
}

sub valid_int {
    my ($self, $int) = @_;
    return Projectus::Valid::valid_int( $int );
}

sub valid_domain {
    my ($self, $domain) = @_;
    return Projectus::Valid::valid_domain( $domain );
}

sub valid_ipv4 {
    my ($self, $ip_address) = @_;
    return Projectus::Valid::valid_ipv4( $ip_address );
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
