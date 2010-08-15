## ----------------------------------------------------------------------------

package CGI::Conduit::Template;

use Moose::Role;

use Template;
use Template::Constants qw( :debug );

## ----------------------------------------------------------------------------

has 'stash' => ( is => 'rw' );

## ----------------------------------------------------------------------------

sub tt {
    my ($self) = @_;

    return $self->{tt} if $self->{tt};

    $self->{tt} = Template->new({
        INCLUDE_PATH => $self->cfg_value('tt_dir'),
    });
    return $self->{tt};
}

sub tt_stash_set {
    my ($self, $key, $value) = @_;
    $self->{stash}{$key} = $value;
}

sub tt_stash_add {
    my ($self, $key, $value) = @_;
    $self->{stash}{$key} ||= [];
    push @{$self->{stash}}, $value;
}

sub tt_stash_del {
    my ($self, $key) = @_;
    delete $self->{stash}{$key};
}

after 'clear' => sub {
    my ($self) = @_;
    $self->{stash} = {};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
