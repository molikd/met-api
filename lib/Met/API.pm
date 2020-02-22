package Met::API;

use strict;
use warnings;

use Switch;
use Dancer qw/:syntax/;
use Dancer::Response;

use MIME::Base64;
use YAML::XS qw/LoadFile/;
use JSON::XS qw/encode_json decode_json/;
use Plack::Handler::Gazelle;

use Dancer::Plugin::Database;
use Dancer::Logger::Met;

our $VERSION = '0.02';

my $name = __PACKAGE__;

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
		driver => 'Pg',
		host   => 'local',
		port   =>  5432,
		user   => 'dmolik',
		dbname => 'met_test',
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
			my $sth  = database->prepare("SELECT * FROM asv,taxon_assignment,taxa WHERE asv.sequence = ? AND asv.id = taxon_assignment.id AND taxon_assignment.taxon_id = taxa.id;") or error "failed to prepare ".database->errstr #wrong;
			my $asv = query_parameters->get('asv');
			$sth->execute($asv) or error "failed to execute stmt ".database->errstr;
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
		get '/name' => sub {
			my @arr;
			for my $qy (qw/ordo familia genus species/) {
				print STDERR params->{$qy}."\n";
				next;
				push ( @arr, ($qy, params->{$qy})) if params->{$qy};
			}
			my $str = "SELECT * FROM taxa WHERE ";
			for my $lvl (@arr) {
				$str .= " $lvl->[0] = '?'";
			}
			my $sth = database->prepare($str) or error "failed to prepare ".database->errstr;
			switch(scalar @arr) {
				case 4 { $sth->execute($arr[0][1], $arr[1][1], $arr[2][1], $arr[3][1]) or error "failed to execute stmt ".database->errstr; }
				case 3 { $sth->execute($arr[0][1], $arr[1][1], $arr[2][1]) or error "failed to execute stmt ".database->errstr; }
				case 2 { $sth->execute($arr[0][1], $arr[1][1]) or error "failed to execute stmt ".database->errstr; }
				case 1 { $sth->execute($arr[0][1]) or error "failed to execute stmt ".database->errstr; }
			}
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
		post '/add' => sub {
			my $order   = query_parameters->get('ordo');
			my $family  = query_parameters->get('familia');
			my $genus   = query_parameters->get('genus');
			my $species = query_parameters->get('species');
			my $sth = database->quick_insert('taxa', { ordo => $order, familia => $family, genus => $genus, species => $species});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/seq_assign' => sub {
			my $taxon_id = query_parameters->get('taxon_id');
			my $sequence = query_parameters->get('sequence');
			my $source = query_parameters->get('source');
			my $external_identifier = query_parameters->get('external_identifier');
			my $sth = database->quick_insert('taxa_seq_id',{taxon_id => $taxon_id, sequence => $sequence, source => $source, external_identifier => $external_identifier});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		}
		# TODO taxa seq assign  INSERT INTO taxa_seq_id (taxon_id, sequence, source, external_identifier) VALUES
		get '/delete' => sub {
			my $id = query_parameters->get('id');
			my $sth = database->quick_delete('taxa',{id => $id });
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
	};

	prefix '/dataset' => sub {
		get '/asv' => sub{ #TODO This is function dataset_asv
			my $asv_id = query_parameters->get('asv_id');
			my $str - "SELECT dataset_asv('$asv_id');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		get '/name' => sub{ #TODO this is dataset_asv_name
			my $external_identifier = query_parameters->get('external_identifier');
			my $str - "SELECT dataset_asv_name('$external_identifier');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		get 'dataset_table' => sub{
			my $dataset_id = query_parameters->get('dataset_id');
			my $str - "SELECT dataset_asv('$dataset_id');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		get 'dataset_taxa_table' => sub{
			my $dataset_id = query_parameters->get('dataset_id');
			my $str - "SELECT dataset_asv_name('$dataset_id');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		post '/add' => sub{
			my $external_identifier = query_parameters->get('external_identifier');
			my $external_name = query_parameters->get('external_name');
			my $external_url = query_parameters->get('external_url');
			my $sth = database->quick_insert('datasets',{external_identifier => $external_identifier, external_name => $external_name, external_url => $external_url});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete' => sub{
			my $dataset_id = query_parameters->get('dataset_id');
			my $sth = database->quick_delete('datasets',{dataset_id => $dataset_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
	};

# TODO this will return taxa functional profile data, waiting for Stephanies updates.
#	prefix '/functional_profile' => sub {
#	};
	#TODO dataset metadata
	#TODO project add/assignment
	#TODO description

	prefix '/asv' => sub {
		get '/select' => {
			my $asv_id = query_parameters->get('asv_id');
			my $sth = database->quick_select('asv',{asv_id => $asv_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		get '/datasets' => {
			my $seq = query_parameters->get('seq');
			my $str - "SELECT asv_dataset('$seq');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		post '/assign_dataset' => { #TODO bulk assign dataset, bulk insert asv
			my $asv_id = query_parameters->get('asv_id');
			my $dataset_id = query_parameters->get('dataset_id');
			my $amount_found = query_parameters->get('amount_found');
			my $sth = database->quick_select('asv_assignment',{asv_id => $asv_id, dataset_id => $dataset_id, amount_found => $amount_found});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/assign_taxa' => {
			my $asv_id = query_parameters->get('asv_id');
			my $taxon_id = query_parameters->get('taxon_id');
			my $assignment_score = query_parameters->get('assignment_score');
			my $assignment_tool = query_parameters->get('assignment_tool');
			my $sth = database->quick_select('taxon_assignment',{asv_id => $asv_id, taxon_id => $taxon_id, assignment_score => $assignment_score, assignment_tool => $assignment_tool});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/add'   => sub {
			my $sequence = query_parameters->get('sequence');
			my $quality_score  = query_parameters->get('quality_score');
			my $gene_region = query_parameters->get('gene_region');
			my $sth = database->quick_insert('asv',{sequence => $sequence, quality_score => $quality_score, gene_region => $gene_region});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete' => sub{
			my $asv_id = query_parameters->get('asv_id');
			my $sth = database->quick_delete('asv',{asv_id => $asv_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
	};

	prefix '/search' => sub {
		get '/asv_datasets' => sub {
			my $asv = query_parameters->get('seq');
			my $str - "SELECT candidate_asv_search('$asv');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
		get '/asv_taxa' = sub {
			my $asv = query_parameters->get('seq');
			my $str - "SELECT candidate_taxon_assignment('$asv');"
			my $sth  = database->prepare($str) or error "failed to prepare ".database->errstr #wrong;
			$sth->execute() or error "failed to execute stmt ".database->errstr;
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
	};


};

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

	#set syslog   => { facility => $CONFIG->{log_facility}, ident => __PACKAGE__, };
	set logger   => 'console';
	if ($CONFIG->{debug}) {
		$CONFIG->{log_level} = 'debug';
		set show_errors =>  1;
	}
	set log           => $CONFIG->{log_level};
	set redis_session => { server => 'localhost', sock => '', database => '', password => ''};
	set session       => 'met';
	set logger_format => '%h %L %m';
	if ($CONFIG->{db}{host} =~ m/local/) {
		$CONFIG->{db}{host} = '';
		delete $CONFIG->{db}{port};
	}
	database($CONFIG->{db});

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

sub run
{
	$server->run(sub {Met::API->dance(Dancer::Request->new(env => shift))});
}

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

Dan Molik, C<< <dan at brgl.org> >>

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

Copyright 2019 David Molik.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

=cut

1; # End of Met::API
