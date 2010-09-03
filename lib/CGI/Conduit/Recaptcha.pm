## ----------------------------------------------------------------------------

package CGI::Conduit::Recaptcha;
use Moose::Role;

## ----------------------------------------------------------------------------

my $standard_challenge_html = <<'EOF';
  <script type="text/javascript"> var RecaptchaOptions = { theme : '__Theme__' }; </script>
  <script type="text/javascript" src="//www.google.com/recaptcha/api/challenge?k=__PubKey__"></script>
  <noscript>
     <iframe src="http://www.google.com/recaptcha/api/noscript?k=__PubKey__" height="300" width="500" frameborder="0"></iframe><br>
     <textarea name="recaptcha_challenge_field" rows="3" cols="40"></textarea>
     <input type="hidden" name="recaptcha_response_field" value="manual_challenge">
  </noscript>
EOF

my $ajax_challenge_html = <<'EOF';
  <script type="text/javascript" src="//www.google.com/recaptcha/api/js/recaptcha_ajax.js"></script>
  <script type="text/javascript">
  // when the user goes to fill in the comment field, show the reCAPTCHA (doesn't show on input[type=checkbox], but we're not too worried
  $('__Form__ input, __Form__ textarea').focus(function(event) {
    // create the reCAPTCHA, but don't call the { callback: Recaptcha.focus_response_field } since we don't want it focussed
    Recaptcha.create( "__PubKey__", "__ID__", { theme: "__Theme__" } );
    // now remove this focus event so it doesn't fire again (see http://api.jquery.com/unbind/)
    $('#comment-form input, #comment-form textarea').unbind( event );
});
</script>
EOF

# From: http://code.google.com/apis/recaptcha/docs/display.html
sub recaptcha_standard_challenge_html {
    my ($self, $theme) = @_;

    $theme ||= 'red';

    # get the recaptcha_public_key
    my $public_key = $self->cfg_value( q{recaptcha_public_key} );

    # generate the HTML
    my $html = $standard_challenge_html;
    $html =~ s{__PubKey__}{$public_key}gxms;
    $html =~ s{__Theme__}{$theme}gxms;
    return $html;
}

# From: http://code.google.com/apis/recaptcha/docs/display.html
sub recaptcha_ajax_html {
    my ($self, $theme, $form, $id) = @_;

    $theme ||= 'red';

    # get the recaptcha_public_key
    my $public_key = $self->cfg_value( q{recaptcha_public_key} );

    # generate the HTML
    my $html = $ajax_challenge_html;
    $html =~ s{__PubKey__}{$public_key}gxms;
    $html =~ s{__Theme__}{$theme}gxms;
    $html =~ s{__Form__}{$form}gxms;
    $html =~ s{__ID__}{$id}gxms;
    return $html;
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
