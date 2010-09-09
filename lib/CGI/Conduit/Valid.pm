## ----------------------------------------------------------------------------

package CGI::Conduit::Valid;

use Moose::Role;

use Data::Validate::Domain qw(is_domain);
use Email::Valid;

## ----------------------------------------------------------------------------

sub valid_int {
    my ($self, $int) = @_;
    return 1 if $int =~ m{ \A \d+ \z }xms;
    return;
}

sub valid_something {
    my ($self, $something) = @_;
    return unless defined $something;
    return 1 if $something =~ m{ \S }xms;
    return;
}

sub valid_domain {
    my ($self, $domain) = @_;
    return 1 if is_domain($domain);
    return;
}

sub valid_ipv4 {
    my ($self, $ip_address) = @_;
    my @octets = split( m{\.}xms, $ip_address );

    warn "o=@octets";

    # check for 4 of them, between 0 and 255 inclusive
    return 0 unless @octets == 4;
    warn "ere";
    foreach my $octet ( @octets ) {
        return 0 unless $self->valid_int($octet);
        return 0 unless ( $octet >= 0 and $octet <= 255 );
    }

    warn "was";

    return 1;
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
