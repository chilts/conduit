## ----------------------------------------------------------------------------

package CGI::Conduit::Valid;

use Moose::Role;

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

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
