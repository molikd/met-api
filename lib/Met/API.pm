package Met::API;

use strict;
use warnings;

use Dancer qw/:syntax/;
use Dancer::Response;

use MIME::Base64;
use YAML::XS qw/LoadFile/;
use JSON::XS qw/encode_json decode_json/;
use Plack::Handler::Gazelle;

use DBI;
use DBD::Pg;
use Dancer::Logger::Met;

use Bio::Tools::dpAlign;
use Bio::SeqIO;
use Bio::SimpleAlign;
use Bio::AlignIO;

our $VERSION = '0.02';


my $name = __PACKAGE__;
my $DB;
our $CONFIG = {
	log_level    => 'info',
	log_facility => 'daemon',
	workers      =>  8,
	keepalive    =>  300,
	port         =>  5000,
	gid          => 'met',
	uid          => 'met',
	pidfile      => '/run/met-api.pid',
	log_file     => '/var/log/met-api.log',
	db           => {
		host   => 'local socket',
		port   =>  5432,
		user   => 'met',
		dbname => 'met',
		pass   => '',
	}
};

get '/' => sub { # {{{
	info '/ hit';
	my $html = qq|
		<!DOCTYPE html>
		<html lang="en_US">
		<head>
			<meta charset="UTF-8">
			<title>$name</title>
		</head>
		<body>
			<center>$name</center>
		</body>
		</html>
	|;
};
# }}}

prefix '/met' => sub {
	# TODO - all deletes need to be privledged access via admin management
	prefix '/taxa' => sub {
		get '/asv' => sub {
			my @otus = query_parameters->get_all('asv');
		};
		get '/name' => sub {
			my $sth     = _db->prepare("SELECT * FROM taxa WHERE ordo = '?' AND familia = '?' AND genus = '?' AND species = '?'") or error "failed to prepare "._db->errstr;
			my $order   = query_parameters->get('ordo');
			my $family  = query_parameters->get('familia');
			my $genus   = query_parameters->get('genus');
			my $species = query_parameters->get('species');
			$sth->execute($order, $family, $genus, $species) or error "failed to execute stmt "._db->errstr;
			my @row;
			my $data = ();
			my $i = 0;
			while (@row = $sth->fetchrow_array()) {
				for (@row) {
					push @{$data->[$i]}, $_;
				}
				$i++;
			}
			content_type 'application/json';
			return encode_json($data);
		};
		post '/add' => sub {};
		get '/delete' => sub {
			my @ids = query_parameters->get_all('id');
		};
	};

	prefix '/assign_asv' => sub {
		get '/asv' => sub {};
	};

	prefix '/place' => sub {
		get '/asv' => sub{
			my $sth  = _db->prepare("SELECT * FROM place WHERE asv = '?'") or error "failed to prepare "._db->errstr;
			my @otus = query_parameters->get_all('asv');
			$sth->execute($otu) or error "failed to execute stmt "._db->errstr;
			my @row;
			my $data = ();
			my $i = 0;
			while (@row = $sth->fetchrow_array()) {
				for (@row) {
					push @{$data->[$i]}, $_;
				}
				$i++;
			}
			content_type 'application/json';
			return encode_json($data);
		};
		get '/name' => sub{
			my $order = query_parameters->get('order');
			my $family = query_parameters->get('family');
			my $genus = query_parameters->get('genus');
			my $species = query_parameters->get('species');
		};
	};

	prefix '/functional_profile' => sub {
		get '/asv' => sub{
			my @asvs = query_parameters->get_all('asv');
		};
		get '/name' => sub{
			my $order = query_parameters->get('order');
			my $family = query_parameters->get('family');
			my $genus = query_parameters->get('genus');
			my $species = query_parameters->get('species');
		};
		post   '' => sub {

		};
		#delete '' => sub {
		#	my @ids = query_parameters->get_all('id');
		#};
	};

	prefix '/asv' => sub {
		post ''   => sub { # add

		};
		#delete '' => sub{
		#	my @ids = query_parameters->get_all('id');
		#};
	};

	prefix '/dataset' => sub {
		post '/add' => sub{};
		get '/delete' => sub{
			my @ids = query_parameters->get_all('id');
		};
	};

	#TODO test, and look at output
	prefix '/search' => sub {
		get '/asv' => sub{
			my $sth   = _db->prepare("SELECT * FROM candidate_asv_search WHERE asv = '?'") or error "failed to prepare "._db->errstr;
			my $asv   = query_parameters->get('asv');
			$sth->execute($asv) or error "failed to execute stmt "._db->errstr;
			my $seq1 = Bio::SeqIO->new(-string => $asv, -format => 'fasta');
			my $factory = new dpAlign(-match => 3,
				-mismatch => -1,
				-gap => 3,
				-ext => 1,
				-alg => Bio::Tools::dpAlign::DPALIGN_LOCAL_MILLER_MYERS);
			my @row;
			my $data = ();
			my $i = 0;
			while (@row = $sth->fetchrow_array()) {
				for (@row) {
					my $seq2 = Bio::SeqIO->new(-string => $_, -format => 'fasta');
					my $aln = $factory->pairwise_alignment($seq1,$seq2)
					push @{$data->[$i]}, $aln;
				}
				$i++;
			}
			
			content_type 'application/json';
			return encode_json($data);
		};
	};

	prefix '/compare' => sub {
		get '/dataset' => sub {
			my $sth_one = _db->prepare("SELECT dataset_asv_name(dataset_one)") or error "failed to prepare "._db->errstr;
			my $sth_two = _db->prepare("SELECT dataset_asv_name(dataset_two)") or error "failed to prepare "._db->errstr;
			my $dataset_one = query_parameters->get('dataset_one');
			my $dataset_two = query_parameters->get('dataset_two');
			$sth_one->execute($dataset_one) or error "failed to execute stmt "._db->errstr;
			$sth_two->execute($dataset_two) or error "failed to execute stmt "._db->errstr;

			#TODO finish this. add bray curtis simularity.
		};
	};
};

sub _db { # {{{
	if (!$DB) {
		my $addr = ",host=$CONFIG->{db}{host},port=$CONFIG->{db}{port}";
		if ($CONFIG->{db}{host} =~ m/local socket/) {
			$addr = '';
		}
		$DB = DBI->connect("dbi:Pg:dbname=$CONFIG->{db}{dbname}$addr", $CONFIG->{db}{user}, $CONFIG->{db}{pass}, { RaiseError => 1 })
			or error "failed to connect to [$CONFIG->{db}{host}/$CONFIG->{db}{dbname}] : ".$DBI::errstr;
	}
	return $DB;
}
# }}}

sub _configure # {{{
{
	my (%OPTIONS) = @_;

	$OPTIONS{config} ||= '/etc/metapi.yml';
	my $config_file;
	if (-f $OPTIONS{config}) {
		eval { $config_file = LoadFile($OPTIONS{config}); 1 }
			or die "Failed to load $OPTIONS{config}: $@\n";
	} else {
		print STDERR "No configuration file found starting|stopping with defaults\n";
	}

	for (keys %$config_file) {
		$CONFIG->{$_} = $config_file->{$_};
		$CONFIG->{$_} = $OPTIONS{$_} if exists $OPTIONS{$_};
	}
	for (keys %OPTIONS) {
		$CONFIG->{$_} = $OPTIONS{$_};
	}

	set syslog   => { facility => $CONFIG->{log_facility}, ident => __PACKAGE__, };
	set logger   => 'met';
	if ($CONFIG->{debug}) {
		$CONFIG->{log_level} = 'debug';
		set show_errors =>  1;
	}
	set log           => $CONFIG->{log_level};
	set redis_session => { server => 'localhost', sock => '', database => '', password => ''};
	set session       => 'met';
	set logger_format => '%h %L %m';

	# set serializer   => 'JSON';
	# set content_type => 'application/json';
}
# }}}

_configure();
info "spawning $name";
my $server = Plack::Handler::Gazelle->new(
	port    => $CONFIG->{port},
	workers => $CONFIG->{workers},
);
$server->run(sub {Met::API->dance(Dancer::Request->new(env => shift))});

=head1 NAME

Met::API - metagenomic enrichment analysis Met::API!


=head1 SYNOPSIS

This code


=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1


=head1 AUTHOR

Dan Molik, C<< <dan at d3fy.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-met-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Met-API>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Met::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Met-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Met-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Met-API>

=item * Search CPAN

L<http://search.cpan.org/dist/Met-API/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2018 Daniel Molik, David Molik.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Met::API
