## ----------------------------------------------------------------------------

package CGI::Conduit::File;

use Moose::Role;
use File::Copy;

## ----------------------------------------------------------------------------

sub file_copy {
    my ($self, $param_name, $dest) = @_;

    my $fh = $self->cgi->upload($param_name);
    return 0 unless defined $fh;

    # rewind so we copy the _entire_ file
    seek($fh, 0, 0);

    # copy this file elsewhere
    copy($fh, $dest);
    return 1;
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
