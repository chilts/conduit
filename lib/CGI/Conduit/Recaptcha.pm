## ----------------------------------------------------------------------------

package CGI::Conduit::Recaptcha;
use Moose::Role;

use LWP::UserAgent;

## ----------------------------------------------------------------------------

my $msgs = {
    'unknown'                  => 'Unknown error.',
    'invalid-site-public-key'  => 'Unable to verify public key.',
    'invalid-site-private-key' => 'Unable to verify private key.',
    'invalid-request-cookie'   => 'The challenge parameter of the verify script was incorrect.',
    'incorrect-captcha-sol'    => 'The CAPTCHA solution was incorrect.',
    'verify-params-incorrect'  => 'Incorrect params when verifying.',
    'invalid-referrer'         => 'reCAPTCHA API keys are tied to a specific domain name for security reasons.',
    'recaptcha-not-reachable'  => 'reCAPTCHA never returns this error code. A plugin should manually return this code in the unlikely event that it is unable to contact the reCAPTCHA verify server.'
};

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
$('#__Form__ input, #__Form__ textarea').focus(function(event) {
    // create the reCAPTCHA but only if it doesn't exist yet
    if ( ! $('#recaptcha_response_field').length ) {
        Recaptcha.create( "__PubKey__", "__ID__", { theme: "__Theme__" } );
    }
    // now remove this focus event so it doesn't fire again (see http://api.jquery.com/unbind/)
    $('#__Form__ input, #__Form__ textarea').unbind( event );
});

// this is for special cases where the user submits without inputting _anything_ at all
$('#__Form__').submit(function() {
    // if there is no #recaptcha_response_field, then show the reCAPTCHA
    if ( ! $('#recaptcha_response_field').length ) {
        Recaptcha.create( "__PubKey__", "__ID__", { theme: "__Theme__" } );
        return false;
    }
});
</script>
EOF

my $verify_url = q{http://www.google.com/recaptcha/api/verify};

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
    my ($self, $theme, $form_id, $id) = @_;

    $theme ||= 'red';

    # get the recaptcha_public_key
    my $public_key = $self->cfg_value( q{recaptcha_public_key} );

    # generate the HTML
    my $html = $ajax_challenge_html;
    $html =~ s{__PubKey__}{$public_key}gxms;
    $html =~ s{__Theme__}{$theme}gxms;
    $html =~ s{__Form__}{$form_id}gxms;
    $html =~ s{__ID__}{$id}gxms;
    return $html;
}

sub recaptcha_verify {
    my ($self, $challenge, $response) = @_;

    my $private_key = $self->cfg_value( q{recaptcha_private_key} );
    my $remote_ip = $self->req_remote_ip();

    my $ua = LWP::UserAgent->new();
    my $resp = $ua->post(
        $verify_url,
        {
            privatekey => $self->cfg_value( q{recaptcha_private_key} ),
            remoteip   => $self->req_remote_ip(),
            challenge  => $challenge,
            response   => $response,
        },
    );

    # see if the verify request was ok
    unless ( $resp->is_success ) {
        # request failed, return 'recaptcha-not-reachable' as recommended by:
        # * http://code.google.com/apis/recaptcha/docs/verify.html
        return { valid => 0, error => 'recaptcha-not-reachable' };
    }
    my ( $valid, $error ) = split( /\n/, $resp->content, 2 );

    # all ok?
    return { valid => 1 }
        if $valid eq 'true';

    # something went wrong (either the user entered wrong, or something else)
    chomp $error;
    return { valid => 0, error => $error };
}

sub recaptcha_error {
    my ($self, $code) = @_;
    return $msgs->{$code};
}

after 'clear' => sub { };

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
