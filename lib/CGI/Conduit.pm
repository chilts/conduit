## ----------------------------------------------------------------------------

package CGI::Conduit;
use strict;
use warnings;

use Data::Dumper;
use Config::Simple;
use Template;
use Template::Constants qw( :debug );
use DBI;
use Cache::Memcached;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors( qw(cfg stash cgi dbh session res_status res_content res_content_type rendered) );

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

    my $path = $self->req_path;
    foreach my $handler ( @{$self->{handler}} ) {
        warn "checking $handler against $handler->{match}";

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
            warn "path=$path";
            warn Dumper($handler->{match});
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

sub cfg_clear {
    # do nothing, since we want to keep it
}

## ----------------------------------------------------------------------------
# cookie stuff

sub cookie {
    my ($self) = @_;
    $self->{cookie} ||= CGI::Cookie->fetch();
    # use Data::Dumper;
    # print Dumper($self->{cookie});
    return $self->{cookie};
}

sub cookie_get {
    my ($self, $name) = @_;
    return $self->cookie->{$name};
}

sub cookie_set {
    my ($self, $name, $value, $opts) = @_;

    # defaults
    my $expire = $opts->{expire} || $self->cfg->{'default-cookie-expiry'} || '+8hr';

    # ToDo: heh, so many stubs ... :)
}

sub cookie_clear {
    my ($self) = @_;
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
    $self->{session} ||= $self->get_session();
    return $self->{session};
}

sub session_set {
    # ToDo: heh, so many stubs ... :)
}

sub get_session {
    my ($self) = @_;

    my $cookie = $self->cookie();

    # get the session cookie
    my $c = $cookie->{session};

    # firstly, check for a session
    unless ( defined $c ) {
        warn "GetSession: No session cookie";
        return;
    }

    # get the value for convenience
    my $value = $c->value();

    # now we need the session store
    # ToDo: this should be Redis, but for now use Pg
    my $dbh = $self->dbh();

    # a session is alluded to
    my $sql = "
        SELECT
            s.id AS s_id, s.name AS s_name,
            a.id AS a_id, a.username AS a_username, a.email AS a_email, a.admin AS a_admin, a.salt AS a_salt
        FROM
            session s
            LEFT JOIN account a ON (s.account_id = a.id)
        WHERE
            s.expiry > datetime('now')
        AND
            s.name = ?
    ";
    my $session = $dbh->selectrow_hashref($sql, undef, $value);

    # check the session exists
    unless ( defined $session ) {
        warn "GetSession: No session in DB (with name $value)";
        # ToDo: should really delete the cookie here
        return;
    }

    warn "GetSession: Session found ($value)";

    # all ok, return it
    return $session;
}

sub session_clear {
    my ($self) = @_;
    $self->{session} = undef;
}

## ----------------------------------------------------------------------------
# memcached

sub memcache {
    my ($self) = @_;

    return $self->{memcache} if $self->{memcache};

    # currently we have no memcache object, so let's create it
    my @servers = $self->cfg_value( q{memcache_servers} );
    my $ns = $self->cfg_value( q{memcache_namespace} );
    warn Dumper(\@servers);

    die 'No memcache servers specified'
        unless @servers;

    $self->{memcache} = Cache::Memcached->new({
        'servers'   => \@servers,
        'namespace' => $ns // '',
    });

    return $self->{memcache};
}

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
        # -cookie => $self->res_cookie,
        @{$self->{res_hdr}},
    );
}

sub render_content {
    my ($self) = @_;

    die 'Page has already been rendered'
        if $self->rendered();

    # headers first, then content, then remember we've done it
    $self->res_header();
    print $self->res_content;
    $self->rendered(1);
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
    $self->render_content();

    return;

    # headers first, then content, then remember we've done it
    $self->res_header();
    $self->tt->process( $template_name, $self->stash() )
        || die $self->tt->error();
    $self->rendered(1);
}

## ----------------------------------------------------------------------------
# get info about the request

sub req_path {
    my ($self) = @_;
    $self->cgi->url( -absolute => 1 )
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

sub http_html_header {
    my ($self) = @_;
    print $self->cgi->header('text/html; charset=utf-8');
}

sub http_not_found {
    my ($self) = @_;
    print $self->cgi->header(
        'text/html; charset=utf-8',
        -status => '404 Not Found',
    );

    print "<h1>404 File not found!</h1>\n";
    # template('404'); # ToDo
}


## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
