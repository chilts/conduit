#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;

use AppsAttic::Conduit;
use CGI::Fast;

## ----------------------------------------------------------------------------

my $app = AppsAttic::Conduit->new();
$app->setup( $ENV{CONDUIT_CFG}, 'website' );

while ( my $cgi = CGI::Fast->new() ) {
    $app->handle($cgi);
}

## ----------------------------------------------------------------------------
