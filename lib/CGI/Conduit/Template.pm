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

    my $location = $self->{stash};

    # turn the key into something we can eval
    $key =~ s{([a-z][a-z0-9_-]*)}{\{$1\}}gxms;
    # can be an array if at the start of the string, or after a dot (not within hashes above e.g. not 'address1')
    $key =~ s{ (?: \A (\d) ) | (?: \.(\d+) ) }{\[$1\]}gxms;
    $key =~ s{\.}{}gxms;

    eval "\$location->$key = \$value";
    if ( $@ ) {
        die $@;
    }
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

    $plural ||= qq{${singular}s};
    $count ||= 0;

    if ( $count == 0 ) {
        return qq{no $plural};
    }
    elsif ( $count == 1 ) {
        return qq{1 $singular};
    }

    # for all other values, use the plural
    return qq{$count $plural};
}

after 'clear' => sub {
    my ($self) = @_;
    $self->{stash} = {};
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
