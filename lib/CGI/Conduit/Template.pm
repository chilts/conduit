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
        ($self->cfg_value('tt_pre_process') ? (PRE_PROCESS => $self->cfg_value('tt_pre_process')) : ()),
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

sub tt_stash_params {
    my ($self, @params) = @_;
    foreach my $name ( @params ) {
        my $value = $self->req_param($name);
        next unless defined $value;
        $self->tt_stash_set( $name, $value );
    }
}

sub tt_stash_del {
    my ($self, $key) = @_;
    delete $self->{stash}{$key};
}

sub tt_pluralise {
    my ($self, $count, $singular, $plural) = @_;

    return "no " . ($plural || $singular)
        if $count == 0;

    return "1 $singular"
        if $count == 1;

    return "$count " . ($plural || $singular);
}

after 'clear' => sub {
    my ($self) = @_;
    $self->{stash} = {};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
