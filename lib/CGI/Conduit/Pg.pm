## ----------------------------------------------------------------------------

package CGI::Conduit::Pg;

use Moose::Role;
use Projectus::Pg qw(get_pg);

## ----------------------------------------------------------------------------

use constant NO_SLICE => { Slice => {} };
has 'pg_obj' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub pg {
    my ($self) = @_;
    return $self->pg_obj || $self->pg_obj( get_pg() );
}

sub pg_begin {
    my ($self) = @_;
    $self->pg->begin_work();
}

sub pg_commit {
    my ($self) = @_;
    $self->pg->commit();
}

sub pg_rollback {
    my ($self) = @_;
    $self->pg->rollback();
}

# returns the last insert ID
sub pg_id {
    my ($self, $sequence) = @_;
    my ($id) = $self->pg->selectrow_array( "SELECT currval(? || '_id_seq')", undef, $sequence );
    return $id;
}

sub pg_row {
    my ($self, $sql, @params) = @_;
    return $self->pg->selectrow_hashref( $sql, undef, @params );
}

sub pg_rows {
    my ($self, $sql, @params) = @_;
    return $self->pg->selectall_arrayref($sql, NO_SLICE, @params );
}

sub pg_do {
    my ($self, $sql, @params) = @_;
    return $self->pg->do($sql, undef, @params );
}

after 'clear' => sub {
    my ($self) = @_;

    # if we're not in a transaction, nothing to do
    return if $self->pg->{AutoCommit};
    # we're in a transaction so we've borked, roll it back
    $self->pg->rollback();
    confess "We've finished the query but were still in a transaction";
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
