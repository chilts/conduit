## ----------------------------------------------------------------------------

package CGI::Conduit::Header;

use Moose::Role;

use Log::Log4perl qw(get_logger);

## ----------------------------------------------------------------------------

has 'hdr' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub hdr_add_header {
    my ($self, $field, $value) = @_;
    push @{$self->{hdr}}, "-$field", $value;
}

sub hdr_no_cache {
    my ($self) = @_;
    # don't do a "Pragma: no-cache" -> http://www.mnot.net/cache_docs/#PRAGMA
    push @{$self->{hdr}}, '-Cache-control', 'no-cache';
}

sub hdr_render {
    my ($self) = @_;
    print $self->cgi->header(
        -type   => $self->res_content_type || 'text/html; charset=utf-8',
        -status => $self->status || 200,
        -cookie => $self->res_cookie,
        @{$self->{hdr}},
    );
}

after 'clear' => sub {
    my ($self) = @_;
    delete $self->{hdr};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
