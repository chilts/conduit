## ----------------------------------------------------------------------------

package CGI::Conduit::Log;

use Moose::Role;

use Log::Log4perl;

## ----------------------------------------------------------------------------

has 'log_obj' => ( is => 'rw' );

my $conf_template = q(
    log4perl.category                 = __LEVEL__, Logfile

    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d (%P) [%-20c;%5L] %-5p: %m%n
    log4perl.appender.Logfile.filename = __FILENAME__
    log4perl.appender.Logfile.mode     = append
);

## ----------------------------------------------------------------------------

# we only need an init function for this Role

after 'init' => sub {
    my ($self) = @_;

    # if we already have the log object, return it
    return $self->log_obj if $self->log_obj;

    # read some config values
    my $filename = $self->cfg_value('log_file');
    my $level = $self->cfg_value('log_level');

    # template them in
    my $conf = $conf_template;
    $conf =~ s{__FILENAME__}{$filename}gxms;
    $conf =~ s{__LEVEL__}{$level}gxms;

    Log::Log4perl::init( \$conf );
};

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
