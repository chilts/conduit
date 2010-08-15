#!/usr/bin/perl
## ----------------------------------------------------------------------------

use Test::More tests => 1;

BEGIN {
	use_ok( 'CGI::Conduit' );
}

diag( "Testing CGI::Conduit $CGI::Conduit::VERSION, Perl $], $^X" );

## ----------------------------------------------------------------------------
