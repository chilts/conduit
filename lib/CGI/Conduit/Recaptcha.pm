## ----------------------------------------------------------------------------

package CGI::Conduit::Recaptcha;
use Moose::Role;

## ----------------------------------------------------------------------------

my $standard_challenge_html = <<'EOF';
  <script type="text/javascript"> var RecaptchaOptions = { theme : '__STYLE__' }; </script>
  <script type="text/javascript" src="http://www.google.com/recaptcha/api/challenge?k=__PK__"></script>
  <noscript>
     <iframe src="http://www.google.com/recaptcha/api/noscript?k=__PK__" height="300" width="500" frameborder="0"></iframe><br>
     <textarea name="recaptcha_challenge_field" rows="3" cols="40"></textarea>
     <input type="hidden" name="recaptcha_response_field" value="manual_challenge">
  </noscript>
EOF

sub recaptcha_standard_challenge_html {
    my ($self, $style) = @_;

    $style ||= 'red';

    # get the recaptcha_public_key
    my $public_key = $self->cfg_value( q{recaptcha_public_key} );

    # generate the HTML
    my $html = $standard_challenge_html;
    $html =~ s{__PK__}{$public_key}gxms;
    $html =~ s{__STYLE__}{$style}gxms;
    return $html;
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
