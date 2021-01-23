package Met::API;

#use strict;
use warnings;

use Switch;
use Dancer qw/:syntax/;
use Dancer::Response;

use MIME::Base64;
use YAML::XS qw/LoadFile/;
use JSON::XS qw/encode_json decode_json/;
use Plack::Handler::Gazelle;

use Dancer::Plugin::Database;
#use Dancer::Logger::Met;

our $VERSION = '0.02';

my $name = __PACKAGE__;

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
			my $sth  == ("SELECT * FROM asv,taxon_assignment,taxa WHERE asv.sequence = ? AND asv.asv_id = taxon_assignment.asv_id AND taxon_assignment.taxon_id = taxa.taxon_id;") or error "failed to prepare ".database->errstr;
			my $asv = param "asv";
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
			my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
		get '/id' => sub {
			my $ordo = param "ordo";
			my $familia = param "familia";
			my $genus = param "genus";
			my $species = param "species";
			my $str = "SELECT taxon_id FROM taxa WHERE ordo = ? AND familia = ? AND genus = ? AND species = ?";
			my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
            $sth->execute($ordo, $familia, $genus, $species) or error "failed to execute stmt ".database->errstr;

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
			my $order   = param "ordo";
			my $family  = param "familia";
			my $genus   = param "genus";
			my $species = param "species";
			my $sth = database()->quick_insert('taxa', { ordo => $order, familia => $family, genus => $genus, species => $species});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/seq_assign' => sub {
			my $taxon_id = param "taxon_id";
			my $sequence = param "sequence";
			my $source = param "source";
			my $external_identifier = param "external_identifier";
			my $sth = database()->quick_insert('taxa_seq_id',{taxon_id => $taxon_id, sequence => $sequence, source => $source, external_identifier => $external_identifier});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete' => sub {
			my $taxon_id = param "taxon_id";
			my $sth = database()->quick_delete('taxa',{taxon_id => $taxon_id });
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/seq_delete' => sub {
            my $seq_id = param "seq_id";
            my $sth = database()->quick_delete('taxa_seq_id',{seq_id => $seq_id });
            content_type 'application/json';
            return encode_json($sth); #TODO - CHECK SYNTAX
        };
	};

	prefix '/dataset' => sub {
		get '/asv' => sub{ #TODO This is function dataset_asv
			my $asv_id = param "asv_id";
			my $str = "SELECT dataset_asv('$asv_id');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
			my $external_identifier = param "external_identifier";
			my $str = "SELECT dataset_asv_name('$external_identifier');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
		get '/dataset_table' => sub{
			my $dataset_id = param "dataset_id";
			my $str = "SELECT dataset_asv('$dataset_id');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
		get '/dataset_taxa_table' => sub{
			my $dataset_id = param "dataset_id";
			my $str = "SELECT dataset_asv_name('$dataset_id');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
			my $external_identifier = param "external_identifier";
			my $external_name = param "external_name";
			my $external_url = param "external_url";
			my $sth = database()->quick_insert('datasets',{external_identifier => $external_identifier, external_name => $external_name, external_url => $external_url});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};

		get '/dataset_id' => sub {
            my $external_identifier = param "external_identifier";
            my $str = "SELECT dataset_id FROM datasets WHERE external_identifier = ?";
            my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
            $sth->execute($external_identifier) or error "failed to execute stmt ".database->errstr;

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

		post '/addmetadata' => sub{
			my $dataset_id = param "dataset_id";
            my $dataset_external_identifier = param "dataset_external_identifier";
			my $project_id = param "project_id";
			my $collection_identifier = param "collection_identifier";
			my $experiment_identifier = param "experiment_identifier";
			my $sample_name = param "sample_name";
			my $study_identifier = param "study_identifier";
			my $assay_type = param "assay_type";
			my $AvgSpotLen = param "AvgSpotLen";
			my $publisher = param "publisher";
			my $collection_date = param "collection_date";
			my $sample_depth = param "sample_depth";
			my $sample_elev = param "sample_elev";
			my $sample_sal = param "sample_sal";
			my $env_biome = param "env_biome";
			my $env_feature = param "env_feature";
			my $env_material = param "env_material";
			my $geo_loc_name_country = param "geo_loc_name_country";
			my $geo_loc_name_country_continent = param "geo_loc_name_country_continent";
			my $geo_loc_name = param "geo_loc_name";
			my $loc_type = param "loc_type";
			my $sequencing_instrument = param "sequencing_instrument";
			my $isolation_source = param "isolation_source";
			my $lat_lon = param "lat_lon";
			my $library_name = param "library_name";
			my $library_layout = param "library_layout";
			my $library_selection = param "library_selection";
			my $library_source = param "library_source";
			my $MBases = param "MBases";
			my $MBytes = param "MBytes";
			my $sequencing_platform = param "sequencing_platform";
			my $release_date = param "release_date";
			my $sth = database()->quick_insert('dataset_metadata',{dataset_id => $dataset_id, dataset_external_identifier => $dataset_external_identifier, project_id => $project_id, collection_identifier => $collection_identifier, experiment_identifier => $experiment_identifier, sample_name => $sample_name, study_identifier => $study_identifier, assay_type => $assay_type, avgspotlen => $AvgSpotLen, publisher => $publisher, collection_date => $collection_date, sample_depth => $sample_depth, sample_elev => $sample_elev, sample_sal => $sample_sal, env_biome => $env_biome, env_feature => $env_feature, env_material => $env_material, geo_loc_name_country => $geo_loc_name_country, geo_loc_name_country_continent => $geo_loc_name_country_continent, geo_loc_name => $geo_loc_name, loc_type => $loc_type, sequencing_instrument => $sequencing_instrument, isolation_source => $isolation_source, lat_lon => $lat_lon, library_name => $library_name, library_layout => $library_layout, library_selection => $library_selection, library_source => $library_source, mbases => $MBases, mbytes => $MBytes, sequencing_platform => $sequencing_platform, release_date => $release_date});
            content_type 'application/json';
            return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete' => sub{
			my $dataset_id = param "dataset_id";
			my $sth = database()->quick_delete('datasets',{dataset_id => $dataset_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
	};

	# TODO this will return taxa functional profile data, waiting for Stephanies updates.
	# prefix '/functional_profile' => sub {
	# };
	#TODO dataset metadata
	
	prefix '/projects' => sub{
        get '/select' => sub{
            my $association_id = param "association_id";
            my $sth = database()->quick_select('projects', {association_id => $association_id});
            content type 'application/json';
            return encode_json($sth);
        };
		post '/add' => sub{
            my $project_name = param "project_name";
            my $external_identifier = param "external_identifier";
            my $external_name = param "external_name";
            my $sth = database()->quick_insert('projects', {project_name => $project_name, external_identifier => $external_identifier, external_name => $external_name});
            content_type 'application/json';
            return encode_json($sth);
        };
        post '/add_total' => sub{
            my $project_name = param "project_name";
            my $external_identifier = param "external_identifier";
            my $external_name = param "external_name";
            my $dataset_ids = param "dataset_ids";
            my $sth = database()->quick_insert('projects', {project_name => $project_name, external_identifier => $external_identifier, external_name => $external_name, dataset_ids => $dataset_ids});
            content_type 'application/json';
            return encode_json($sth);
        };
        post '/delete' => sub{
            my $association_id = param "association_id";
            my $sth = database()->quick_delete('projects', {association_id => $association_id});
            content_type 'application/json';
            return encode_json($sth);
        };
		post '/update' => sub{
			my $dataset_id = param "dataset_id";
			my $project_name = param "project_name";
			my $str = "UPDATE projects SET dataset_ids = array_append(dataset_ids, ?) WHERE project_name = ?";
			my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
			$sth->execute($dataset_id, $project_name) or error "failed to execute stmt ".database->errstr;
			content_type 'application/json';
			return encode_json($sth);
		};
		get '/project_id' => sub {
            my $external_identifier = param "external_identifier";
            my $str = "SELECT association_id FROM projects WHERE external_identifier = ?";
            my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
            $sth->execute($external_identifier) or error "failed to execute stmt ".database->errstr;

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

	prefix '/description' => sub{
        get '/select' => sub{
            my $description_id = param "description_id";
            my $sth = database()->quick_select('descriptions', {description_id => $description_id});
            content_type 'application/json';
            return encode_json($sth);
        };
        post '/add' => sub{
            my $taxon_id = param "taxon_id";
            my $description = param "description";
            my $name = param "name";
            my $sth = database()->quick_insert('descriptions', {taxon_id => $taxon_id, description => $description, name => $name});
            content_type 'application/json';
            return encode_json($sth);
        };
        post '/delete' => sub{
            my $description_id = param "description_id";
            my $sth = database()->quick_delete('descriptions', {description_id => $description_id});
            content_type 'application/json';
            return encode_json($sth);
        };
    };

	prefix '/asv' => sub{
		get '/select' => sub{
			my $asv_id = param "asv_id";
			my $sth = database()->quick_select('asv',{asv_id => $asv_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		get '/datasets' => sub{
			my $seq = param "seq";
			my $str = "SELECT asv_dataset('$seq');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
		post '/assign_dataset' => sub{ #TODO bulk assign dataset, bulk insert asv
			my $asv_id = param "asv_id";
			my $dataset_id = param "dataset_id";
			my $amount_found = param "amount_found";
			my $sth = database()->quick_insert('asv_assignment',{asv_id => $asv_id, dataset_id => $dataset_id, amount_found => $amount_found});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete_dataset' => sub{
            my $asv_assignment_id = param "asv_assignment_id";
            my $sth = database()->quick_delete('asv_assignment',{asv_assignment_id => $asv_assignment_id});
            content_type 'application/json';
            return encode_json($sth); #TODO - CHECK SYNTAX
        };
		post '/assign_taxa' => sub{
			my $asv_id = param "asv_id";
			my $taxon_id = param "taxon_id";
			my $assignment_score = param "assignment_score";
			my $assignment_tool = param "assignment_tool";
			my $sth = database()->quick_insert('taxon_assignment',{asv_id => $asv_id, taxon_id => $taxon_id, assignment_score => $assignment_score, assignment_tool => $assignment_tool});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/add'   => sub {
			my $sequence = param "sequence";
			my $quality_score  = param "quality_score";
			my $gene_region = param "gene_region";
			my $sth = database()->quick_insert('asv',{sequence => $sequence, quality_score => $quality_score, gene_region => $gene_region});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		post '/delete' => sub{
			my $asv_id = param "asv_id";
			my $sth = database()->quick_delete('asv',{asv_id => $asv_id});
			content_type 'application/json';
			return encode_json($sth); #TODO - CHECK SYNTAX
		};
		get '/asv_id' => sub {
            my $sequence = param "sequence";
            my $str = "SELECT asv_id FROM asv WHERE sequence = ?";
            my $sth = database()->prepare($str) or error "failed to prepare ".database->errstr;
            $sth->execute($sequence) or error "failed to execute stmt ".database->errstr;

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

	prefix '/search' => sub {
		get '/asv_datasets' => sub {
			my $asv = param "seq";
			my $str = "SELECT candidate_asv_search('$asv');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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
		get '/asv_taxa' => sub {
			my $asv = param "seq";
			my $str = "SELECT candidate_taxon_assignment('$asv');";
			my $sth  = database()->prepare($str) or error "failed to prepare ".database->errstr;
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

#sub _configure # {{{
#{
	#my (%OPTIONS) = @_;

	#	$OPTIONS{config} ||= 'config.yml';
	#	my $config_file;
	#	if (-f $OPTIONS{config}) {
	#		eval { $config_file = LoadFile($OPTIONS{config}); 1 }
	#			or die "Failed to load $OPTIONS{config}: $@\n";
	#	} else {
	#		print STDERR "No configuration file found starting|stopping with defaults\n";
	#	}

	#	for (keys %$config_file) {
	#		$CONFIG->{$_} = $config_file->{$_};
	#		$CONFIG->{$_} = $OPTIONS{$_} if exists $OPTIONS{$_};
	#	}
	#	for (keys %OPTIONS) {
	#		$CONFIG->{$_} = $OPTIONS{$_};
	#	}

	#set syslog   => { facility => $CONFIG->{log_facility}, ident => __PACKAGE__, };
	#set logger   => 'console';
	#if ($CONFIG->{debug}) {
	#	$CONFIG->{log_level} = 'debug';
	#		set show_errors =>  1;
	#	}
	#set log           => config->{log_level};
	#set redis_session => { server => 'localhost', sock => '', database => '', password => ''};
	#set session       => 'met';
	#set logger_format => '%h %L %m';
	#	if ({host} =~ m/local/) {
	#		{host} = '';
	#		delete {port};
	#	}
	#database();

	# set serializer   => 'JSON';
	# set content_type => 'application/json';
	#}
# }}} 

#_configure();
#info "spawning $name";
#my $server = Plack::Handler::Gazelle->new(
#	port    => config->{port},
#	workers => config->{workers},
#);

#sub run
#{
#	$server->run(sub {Met::API->dance(Dancer::Request->new(env => shift))});
#}

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
