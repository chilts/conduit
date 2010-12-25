## ----------------------------------------------------------------------------

package CGI::Conduit::File;

use Carp qw(croak);
use Moose::Role;
use File::Basename;
use File::Copy;
use File::Slurp;

with 'CGI::Conduit::Log';

use Log::Log4perl qw(get_logger);

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

sub render_file {
    my ($self, $filename, $path_to_file) = @_;

    # if the file doesn't exist, croak
    unless ( -f $path_to_file ) {
        my $log = get_logger();
        my $msg = qq{File '$path_to_file' doesn't exist};
        $log->fatal( $msg );
        croak $msg;
    }

    # read whole file in
    my $data = read_file( $path_to_file, binmode => ':raw' );
    my $size = -s $path_to_file;

    # remove all newlines from the filename
    $filename =~ s{[\n\r]+}{}gxms;

    # add some headers
    $self->hdr_add_header( q{Content-Length},      $size );
    $self->hdr_add_header( q{Content-Disposition}, qq{attachment; filename="$filename"} );

    # render the header and file with the correct content type
    $self->render_content_with_type(
        'application/octet-stream',
        $data,
    );
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
