#!/usr/bin/perl
## ----------------------------------------------------------------------------

use Test::More tests => 3;

use CGI::Conduit;
use Data::Dumper;

{
    package MyApp;
    use Moose;
    extends 'CGI::Conduit';
    with qw(CGI::Conduit::Memcache);

    sub setup_handlers {
        my $self = shift;
    }
}

# load the basic condif
my $app = MyApp->new();

is( $app->isa('Moose::Object'), 1, 'check the MyApp is Moose::Object' );
is( $app->isa('CGI::Conduit'), 1, 'check the MyApp is CGI::Conduit' );
is( $app->does('CGI::Conduit::Memcache'), 1, 'check the MyApp does CGI::Conduit::Memcache' );

$app->setup( 't/basic.cfg' );

## ----------------------------------------------------------------------------
