#!/usr/bin/perl
## ----------------------------------------------------------------------------

use strict;
use warnings;

use AppsAttic::Conduit;
# use CGI::Fast qw(:standard start_ul);
use CGI::Fast;

## ----------------------------------------------------------------------------

my $app = AppsAttic::Conduit->new();

$app->setup();

while ( my $cgi = CGI::Fast->new() ) {
    $app->handle($cgi);
}

## ----------------------------------------------------------------------------
