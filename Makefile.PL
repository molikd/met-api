use 5.006;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME             => 'Met::API',
	AUTHOR           => q{Dan Molik <dan@d3fy.net>},
	VERSION_FROM     => 'lib/Met/API.pm',
	ABSTRACT_FROM    => 'lib/Met/API.pm',
	LICENSE          => 'artistic_2',
	PL_FILES         => {},
	MIN_PERL_VERSION => '5.006',
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '0',
	},
	EXE_FILES => [
		'bin/met-api',
	],
	TEST_REQUIRES => {
		'Test::More' => '0',
	},
	BUILD_REQUIRES => {
	},
	PREREQ_PM => {
		'Dancer'                    => 0,
		'YAML::XS'                  => 0,
		'JSON::XS'                  => 0,
		'Redis::hiredis'            => 0,
		'MIME::Base64'              => 0,
		'Gazelle'                   => 0,
		'DBI'                       => 0,
		'DBD::Pg'                   => 0,
		'Sys::Syslog'               => 0,
		'Dancer::Plugin::Database'  => 0,
	},
	dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean => { FILES => 'Met-API-*' },
);
