use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'WWW::CEXIO::API',
    AUTHOR           => q{Colin Wetherbee <cww@cpan.org>},
    VERSION_FROM     => 'lib/WWW/CEXIO/API.pm',
    ABSTRACT_FROM    => 'lib/WWW/CEXIO/API.pm',
    LICENSE          => 'MIT',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.10.0',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Carp'           => 1.29,
        'common::sense'  => 3.72,
        'JSON'           => 2.61,
        'LWP::UserAgent' => 6.05,
        'Moose'          => 2.1005,
        'Digest::SHA'    => 5.003000,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'WWW-CEXIO-API-*' },
);
