## ----------------------------------------------------------------------------

package CGI::Conduit;
use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use Config::Simple;
use CGI::Cookie;
use DBI;
use Cache::Memcached;
use Template;
use Template::Constants qw( :debug );
use String::Random::NiceURL qw(id);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors( qw(cfg stash cgi dbh session session_id res_status res_cookie res_content res_content_type rendered) );

## ----------------------------------------------------------------------------
# setup, handlers dispatchers and suchlike

sub setup {
    my ($self, $filename) = @_;

    # use either filename passed in or the the ENV
    $filename ||= $ENV{CONDUIT_CFG};

    # check the file exists
    -f $filename
        or die "Config file doesn't exist: $!";

    # read in and set the config
    $self->cfg( Config::Simple->new( $filename ) );

    # this should be provided by the inheriting class
    $self->setup_handlers();
}

sub setup_handlers {
    die 'setup_handlers(): should be provided by the inheriting class';
}

sub add_handler {
    my ($self, $match, $handler) = @_;

    push @{$self->{handler}}, { match => $match, name => $handler };
}

sub reset {
    my ($self) = @_;
    # don't do: cfg, dbh, memcache, redis or tt
    $self->cookie_clear();
    $self->session_clear();
    $self->stash_clear();
    $self->rendered(0);
}

sub handle {
    my ($self, $cgi) = @_;

    # clear everything we know then set the cgi object
    $self->reset();
    $self->cgi($cgi);

    eval {
        $self->dispatch();
    };
    if ( $@ ) {
        # if we are here, something went wrong, so serve a 500
        warn "Application died: $@";
        $self->http_internal_server_error();
    }
}

sub dispatch {
    my ($self) = @_;

    my $path = $self->req_path;
    foreach my $handler ( @{$self->{handler}} ) {
        if ( ref $handler->{match} eq 'Regexp' ) {
            if ( $path =~ $handler->{match} ) {
                my $name = $handler->{name};
                $self->$name();
                return;
            }
        }
        elsif ( ref $handler->{match} eq 'ARRAY' ) {
            foreach my $redirect_path ( @{$handler->{match}} ) {
                if ( $redirect_path eq $path ) {
                    my $name = $handler->{name};
                    $self->$name();
                    return;
                }
            }
        }
        elsif ( ref $handler->{match} eq 'HASH' ) {
            if ( exists $handler->{match}{$path} ) {
                my $name = $handler->{name};
                $self->$name();
                return;
            }
        }
        elsif ( defined $handler->{match} ) {
            if ( $handler->{match} eq $path ) {
                my $name = $handler->{name};
                $self->$name();
                # $self->"$handler->{name}"();
                return;
            }
        }
    }

    # if we are here, then we haven't been told what to do, 404 it
    $self->http_not_found();
}

## ----------------------------------------------------------------------------
# config (cfg)

sub cfg_value {
    my ($self, $key) = @_;
    return $self->cfg->param($key);
}

## ----------------------------------------------------------------------------
# cookie stuff

sub cookie {
    my ($self) = @_;

    return $self->{cookie} if $self->{cookie};

    # get them from CGI::Cookie
    my %cookies = CGI::Cookie->fetch();
    $self->{cookie} = \%cookies;
    return $self->{cookie};
}

sub cookie_get {
    my ($self, $name) = @_;
    return $self->cookie->{$name};
}

sub cookie_set {
    my ($self, $name, $value, $opts) = @_;

    # defaults
    $opts ||= {};
    my $expire = $opts->{expire} || '+8hr';

    my $c = CGI::Cookie->new(
        -name    =>  $name,
        -value   =>  $value,
        -expires =>  $expire
    );

    # add this cookie to the response cookie list
    push @{$self->{res_cookie}}, $c;
}

sub cookie_del {
    my ($self, $name) = @_;
    $self->cookie_set($name, '', { expire => '-3d' } );
}

sub cookie_clear {
    my ($self, $name) = @_;
    $self->{cookie} = undef;
}

## ----------------------------------------------------------------------------
# database (db) stuff

sub dbh {
    my ($self) = @_;

    return $self->{dbh} if $self->{dbh};

    # get any config options
    my $db_name = $self->cfg_value( q{db_name} );
    my $db_user = $self->cfg_value( q{db_user} );
    my $db_pass = $self->cfg_value( q{db_pass} );
    my $db_host = $self->cfg_value( q{db_host} );
    my $db_port = $self->cfg_value( q{db_port} );

    # make the connection string
    my $connect_str = qq{dbi:pg:dbname=$db_name};
    $connect_str .= qq{;host=$db_host} if $db_host;
    $connect_str .= qq{;port=$db_port} if $db_host;

    # connect to the DB
    $self->{dbh} = DBI->connect(
        "dbi:Pg:dbname=$db_name",
        $db_user,
        $db_pass,
        {
            AutoCommit => 1, # act like psql
            PrintError => 0, # don't print anything, we'll do it ourselves
            RaiseError => 1, # always raise an error with something nasty
        }
    );

    return $self->{dbh};
}

## ----------------------------------------------------------------------------
# session stuff

sub session {
    my ($self) = @_;

    # if we already have the session, return it
    return $self->{session} if $self->{session};

    # firstly, check for a session cookie
    my $cookie = $self->cookie_get('session');
    return unless defined $cookie;

    # get the cookie value which is the session id and check it for validity
    my $id = $cookie->value();
    unless ( $self->is_session_id_valid($id) ) {
        warn qq{session(): session id '$id' invalid};
        $self->cookie_del( q{session} );
        return;
    }

    # retrieve the session
    my $session = $self->session_get( $id );
    unless ( defined $session ) {
        warn qq{session(): session id '$id' doesn't exist};
        $self->cookie_del( q{session} );
        return;
    }

    # remember the session and it's id
    $self->session_id( $id );
    $self->{session} = $session;

    # return the session
    return $session;
}

sub is_session_id_valid {
    my ($self, $id) = @_;
    return 1 if $id =~ m{ \A [A-Za-z0-9-_]{32} \z }xms;
    return;
}

sub session_new {
    my ($self, $value) = @_;

    croak qq{Trying to set a session to undef}
        unless $value;

    my $id = id(32);
    my $mc = $self->memcache();
    unless ( $mc->set("session:$id", $value) ) {
        warn "session_new(): Trying to set session $id failed";
        return;
    }

    # setting the session worked, so set the appropriate bits and return the id
    $self->cookie_set( q{session}, $id );
    $self->session_id($id);
    $self->{session} = $value;
    return $id;
}

sub session_set {
    my ($self, $id, $value) = @_;

    croak qq{Trying to set a session to undef}
        unless $value;

    my $mc = $self->memcache();
    $mc->set("session:$id", $value);
}

sub session_get {
    my ($self, $id) = @_;

    # no need to check for a valid session id since that's already been done,
    # so just return the session if it's there
    return $self->memcache()->get( qq{session:$id} );
}

sub session_del {
    my ($self) = @_;

    unless ( $self->session ) {
        croak "session_del(): trying to delete a session which doesn't (yet) exist";
        return;
    }

    my $id = $self->session_id();

    # remove from memcache, set a cookie and clear what we have
    $self->memcache->delete( qq{session:$id} );
    $self->cookie_del( q{session} );
    delete $self->cookie->{session};
    $self->session_clear();
}

sub session_clear {
    my ($self) = @_;
    delete $self->{session};
    delete $self->{session_id};
}

## ----------------------------------------------------------------------------
# memcache

sub memcache {
    my ($self) = @_;

    return $self->{memcache} if $self->{memcache};

    # currently we have no memcache object, so let's create it
    my @servers = $self->cfg_value( q{memcache_servers} );
    my $ns = $self->cfg_value( q{memcache_namespace} );

    die 'No memcache servers specified'
        unless @servers;

    $self->{memcache} = Cache::Memcached->new({
        'servers'   => \@servers,
        'namespace' => $ns // '',
    });

    return $self->{memcache};
}

# sub memcache_incr (so we don't have to write the weird stuff all the time)

## ----------------------------------------------------------------------------
# redis

# ToDo

## ----------------------------------------------------------------------------
# templating stuff

sub tt {
    my ($self) = @_;

    return $self->{tt} if $self->{tt};

    $self->{tt} = Template->new({
        INCLUDE_PATH => $self->cfg_value('tt_dir'),
    });
    return $self->{tt};
}

sub stash_set {
    my ($self, $key, $value) = @_;
    $self->{stash}{$key} = $value;
}

sub stash_add {
    my ($self, $key, $value) = @_;
    $self->{stash}{$key} ||= [];
    push @{$self->{stash}}, $value;
}

sub stash_del {
    my ($self, $key) = @_;
    delete $self->{stash}{$key};
}

sub stash_clear {
    my ($self) = @_;
    $self->{stash} = {};
}

sub res_add_header {
    my ($self, $field, $value) = @_;
    push @{$self->{res_hdr}}, "-$field", $value;
}

# res_status
# res_content_type

sub res_header {
    my ($self) = @_;
    print $self->cgi->header(
        -type   => $self->res_content_type || 'text/html; charset=utf-8',
        -status => $self->res_status || 200,
        -cookie => $self->res_cookie,
        @{$self->{res_hdr}},
    );
}

sub render_final {
    my ($self) = @_;

    # check if we have already been rendered
    die 'Page has already been rendered'
        if $self->rendered();

    # headers first, then content, then remember we've done it
    $self->res_header();
    print $self->res_content;
    $self->rendered(1);
}

sub render_content {
    my ($self, $content) = @_;
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
    $self->stash_set('conduit', $self);

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
    $self->cgi->url();
}

sub req_path {
    my ($self) = @_;
    $self->cgi->url( -absolute => 1 );
}

sub req_method {
    my ($self) = @_;
    $self->cgi->request_method();
}

sub req_referer {
    my ($self) = @_;
    $self->cgi->referer();
}

sub req_remote_ip {
    my ($self) = @_;
    $self->cgi->remote_host();
}

sub req_params {
    my ($self) = @_;

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
        die "ToDo: We never actually get in here, so this code can be removed";
        $params{$kw} = '';
    }

    # process the incoming parameters into arrays if they contain \0's
    foreach my $param ( keys %params ) {
        next unless $params{$param} =~ m{\0}xms;
        # use of -1 means don't strip trailing empty slots
        $params{$param} = [ split('\0', $params{$param}, -1) ];
    }
    return \%params;
}

## ----------------------------------------------------------------------------
# easy canned responses

sub http_temp_redirect {
    my ($self, $url) = @_;
    print $self->cgi->redirect(
        -uri    => $url,
        -status => 302,
    );
}

sub http_moved_permanently {
    my ($self, $url) = @_;
    print $self->cgi->redirect(
        -uri    => $url,
        -status => 301,
    );
}

sub http_not_found {
    my ($self) = @_;
    $self->res_status(404);
    $self->render_template( q{404.html} );
}

sub http_internal_server_error {
    my ($self) = @_;
    $self->res_status(500);
    $self->render_template( q{500.html} );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
