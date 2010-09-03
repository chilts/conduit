## ----------------------------------------------------------------------------

package CGI::Conduit::Convert;

use Log::Log4perl qw(get_logger);
use Moose::Role;
use HTML::Scrubber;

my $log = get_logger();
my $scrubber = HTML::Scrubber->new(
    allow => [ qw[ p b i u strong em hr br ] ],
    rules => [
        a => {
            href => qr{^http://}i, # only allow fully qualified links
        },
    ],
    default => [
        0, # default, deny all tags
        {
            '*' => 0, # disallow all attributes, unless told otherwise
        }
    ],
);

## ----------------------------------------------------------------------------

sub convert_text_to_scrubbed_html {
    my ($self, $text) = @_;

    # simple if nothing there
    return '<p></p>' unless defined $text;

    # remove weird \r chars
    $text =~ s{\r+}{}gxms;

    # split up and rejoin each paragraph (no matter how many \n's between them)
    my @paras = split( m{\n+}xms, $text );
    my $html = '<p>' . join( "</p>\n<p>", @paras ) . '</p>';

    # now, scrub the HTML so it'll be nice
    $html = $scrubber->scrub($html);

    return $html;
}

sub convert_remove_newlines {
    my ($self, $text) = @_;
    # replace each set with a single space
    $text =~ s{[\r\n]+}{ }gxms;
    return $text;
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
