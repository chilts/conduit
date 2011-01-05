## ----------------------------------------------------------------------------

package CGI::Conduit;

use Carp;
use Moose;
use Log::Log4perl qw(get_logger);
use URI::Escape;

# use the core roles
with qw(
    CGI::Conduit::Header
    CGI::Conduit::Status
    CGI::Conduit::Cfg
    CGI::Conduit::Cookie
    CGI::Conduit::Log
);

our $VERSION = '0.05';

## ----------------------------------------------------------------------------
# accessors

has 'cgi' => ( is => 'rw' );
has 'params_save' => ( is => 'rw' );
has 'res_content' => ( is => 'rw' );
has 'res_content_type' => ( is => 'rw' );
has 'rendered' => ( is => 'rw' );

## ----------------------------------------------------------------------------
# setup and initialisation

sub setup {
    my ($self, $cfg_filename, $log_filename) = @_;

    # check the config filename is given (log filename is optional)
    defined $cfg_filename
        or croak "Config filename not given";

    # check the config file exists
    -f $cfg_filename
        or croak "Config file doesn't exist: $!";

    # load up the config
    $self->cfg_load( $cfg_filename );

    # set the log file (whether it is defined or not)
    $self->log_filename( $log_filename );

    # finally, call the init function (which some roles hook to 'after')
    $self->init();
}

# this should eventually be moved to 'setup', though the roles then need
# changing so they hook into 'after setup' rather than 'after init'
sub init {
    my $self = shift;

    # 'setup_handlers' should be provided by the inheriting class
    $self->setup_handlers();
}

sub setup_handlers {
    die 'setup_handlers(): should be provided by the inheriting class';
}

sub clear {
    my $self = shift;
    $self->params_save(undef);
    delete $self->{res_content_type};
    $self->rendered(0);
}

## ----------------------------------------------------------------------------
# handle stuff

sub add_handler {
    my ($self, $match, $handler, $attr) = @_;

    # default to nothing
    $attr ||= {};

    push @{$self->{handler}}, { match => $match, name => $handler, attr => $attr };
}

sub handle {
    my ($self, $cgi) = @_;

    # clear everything we know then set the cgi object
    $self->clear();
    $self->cgi($cgi);

    eval {
        my ($handler, @captures) = $self->get_handler();

        if ( $handler ) {
            # we have something, but before we do anything, run the triggers
            my $done = 0;
            foreach my $before ( @{$handler->{attr}{before}} ) {
                next if $done;
                if ( $self->$before( @captures ) ) {
                    $done = 1;
                }
            }

            # if we're already done, don't run the main handler
            unless ( $done ) {
                my $method = $handler->{name};
                $self->$method( @captures );
            }

            # run ALL of the after triggers
            foreach my $after ( @{$handler->{attr}{after}} ) {
                $self->$after( @captures );
            }
        }
        else {
            # if we are here, then we haven't been told what to do, 404 it
            $self->status_not_found();
        }
    };
    if ( $@ ) {
        # something went wrong, log it to both serverlog and ours and serve a 500
        my $msg = qq{Application died: $@};
        my $log = get_logger();
        $log->fatal( $msg );;
        warn $msg;
        $self->status_internal_server_error();
    }
}

sub get_handler {
    my ($self) = @_;

    my $path = $self->req_path;
    foreach my $handler ( @{$self->{handler}} ) {
        if ( ref $handler->{match} eq 'Regexp' ) {
            if ( my @matches = $path =~ $handler->{match} ) {
                @matches = ($path) unless @matches;
                $_ = uri_unescape($_)
                    for @matches;
                return ( $handler, @matches );
            }
        }
        elsif ( ref $handler->{match} eq 'ARRAY' ) {
            foreach my $redirect_path ( @{$handler->{match}} ) {
                return ( $handler, $path )
                    if $redirect_path eq $path;
            }
        }
        elsif ( ref $handler->{match} eq 'HASH' ) {
            return ( $handler, $path )
                if exists $handler->{match}{$path};
        }
        elsif ( defined $handler->{match} ) {
            return ( $handler )
                if $handler->{match} eq $path;
        }
    }

    # we didn't find anything that matches, therefore there is no handler
    return;
}

## ----------------------------------------------------------------------------

# res_content_type

sub render_final {
    my ($self) = @_;

    # check if we have already been rendered
    die 'Page has already been rendered'
        if $self->rendered();

    # headers first, then content, then remember we've done it
    $self->hdr_render();
    print $self->res_content;
    $self->rendered(1);
}

sub render_content {
    my ($self, $content) = @_;
    $self->res_content($content);
    $self->render_final();
}

sub render_content_with_type {
    my ($self, $type, $content) = @_;
    $self->res_content_type($type);
    $self->res_content($content);
    $self->render_final();
}

sub render_template {
    my ($self, $template_name) = @_;

    die 'Page has already been rendered'
        if $self->rendered();

    die 'No template specified'
        unless defined $template_name;

    # pass ourself (a conduit object) to the template, so it can get things
    $self->tt_stash_set('conduit', $self);

    # since rendering the Template could die, render first to a variable
    # then call the render_content method
    my $content;
    $self->tt->process( $template_name, $self->stash(), \$content )
        || die $self->tt->error();
    $self->res_content($content);
    $self->render_final();
}

## ----------------------------------------------------------------------------
# get info about the request

sub req_url {
    my ($self) = @_;
    return $self->cgi->url();
}

sub req_path {
    my ($self) = @_;
    return $self->cgi->url( -absolute => 1 );
}

sub req_method {
    my ($self) = @_;
    return $self->cgi->request_method();
}

sub req_referer {
    my ($self) = @_;
    return $self->cgi->referer();
}

sub req_remote_ip {
    my ($self) = @_;
    return $self->cgi->remote_host();
}

sub req_query_string {
    my ($self) = @_;
    return $self->cgi->query_string();
}

sub req_param {
    my ($self, $param_name) = @_;
    my $params = $self->req_params;
    return $params->{$param_name};
}

sub req_param_list {
    my ($self, $param_name) = @_;
    my $params = $self->req_params;

    return [] unless defined $params->{$param_name};

    return ref $params->{$param_name} eq 'ARRAY'
        ? $params->{$param_name}
        : [ $params->{$param_name} ]
    ;
}

sub req_params {
    my ($self) = @_;

    # if we already have it, return it and don't compute it again
    return $self->params_save if $self->params_save();

    # Note: this returns a copy of the hash (and not a tied hash, which we don't want)
    my %params = $self->cgi->Vars;

    # NOTE: $params{keywords} is set if the value is the only key in the query
    # and it has no value
    #
    # e.g. ?this
    #
    # It is _not_ set in the following (and all other) circumstances:
    # - ?this=
    # - ?this&this
    # - ?this&that
    #
    # and we're not ever going to use it
    # ie. /path?this        # makes a string : keywords => 'this'
    # ie. /path?this+that   # makes an array : keywords => ['this','that']
    #
    if ( my $kw = delete $params{keywords} ) {
        $params{$kw} = '';
    }

    # process the incoming parameters into arrays if they contain \0's
    foreach my $param ( keys %params ) {
        next unless $params{$param} =~ m{\0}xms;
        # use of -1 means don't strip trailing empty slots
        $params{$param} = [ split('\0', $params{$param}, -1) ];
    }

    # save for next time and return it
    $self->params_save( \%params );
    return \%params;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------

=head1 NAME

CGI::Conduit - base class for nice CGI::Fast web applications

=head1 VERSION

Version 0.04

=head1 SYNOPSIS

    use MyWebsite;
    use CGI::Fast;

    my $app = MyWebsite->new();
    $app->setup();
    while ( my $cgi = CGI::Fast->new() ) {
        $app->handle($cgi);
    }

Meanwhile ...

    package MyWebsite;
    use Moose;
    extends 'CGI::Conduit';

    with qw(); # add other CGI::Conduit::* roles you need here

    sub setup_handlers {
        my ($self) = @_;
        $self->add_handler( '/', 'page_home' );
    }

    sub page_home {
        my ($self) = @_;
        $self->render_content('<p>Hello, World!</p>');
    }

    1;

=head1 DESCRIPTION

This module allows you to setup a number of parts of your web application using
only a config file. This includes things like connections to your database,
memcache servers, redis, use of Template::Toolkit, and finally cookie and
session dealings.

There are some core roles in CGI::Conduit::* but also some optional ones
too. If you need any of these, just make sure you include the role in your
application module as above.

=head1 BUGS

Please report bugs to C<< <chilts at appsattic dot com> >>

=head1 SUPPORT

Currently there is none since this module isn't yet officially released, but
you can email me if you like.

=head1 AUTHOR, COPYRIGHT & LICENSE

Andrew Chilton, C<< <chilts at appsattic dot com> >>

Copyright (c) 2010, Apps Attic Ltd, all rights reserved.

L<http://www.appsattic.com/>

This module is free software. You can redistribute it and/or modify it under
the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but without any
warranty; without even the implied warranty of merchantability or fitness for a
particular purpose.

=cut
