use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CGI::Conduit',
    AUTHOR              => 'Andrew Chilton <chilts@appsattic.com>',
    VERSION_FROM        => 'lib/CGI/Conduit.pm',
    ABSTRACT_FROM       => 'lib/CGI/Conduit.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'DBI' => 0,
        'DBD::Pg' => 0,
        'Cache::Memcached' => 0,
        'CGI' => 0,
        'CGI::Cookie' => 0,
        'Config::Simple' => 0,
        'Template' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CGI-Conduit-*' },
);
