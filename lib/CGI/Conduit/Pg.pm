## ----------------------------------------------------------------------------

package CGI::Conduit::Pg;

use Moose::Role;

use DBI;

## ----------------------------------------------------------------------------

has 'pg_dbh' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub pg {
    my ($self) = @_;

    return $self->pg_dbh if $self->pg_dbh;

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
    my $dbh = DBI->connect(
        "dbi:Pg:dbname=$db_name",
        $db_user,
        $db_pass,
        {
            AutoCommit => 1, # act like psql
            PrintError => 0, # don't print anything, we'll do it ourselves
            RaiseError => 1, # always raise an error with something nasty
        }
    );

    # save it and return
    $self->pg_dbh($dbh);
    return $self->pg_dbh;
}

after 'clear' => sub {
    # if we're not in a transaction, nothing to do
    return if $self->pg->{AutoCommit};
    # we're in a transaction so we've borked, roll it back
    $self->pg->rollback();
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
