#!/usr/bin/perl

use DBI;

# Connection config
my $dbname = 'MET';
my $host = '127.0.0.1';
my $port = 5432;
my $username = 'user';
my $password = 'password';

# Create DB handle object by connecting
my $dbh = DBI -> connect("dbi:Pg:dbname=$dbname;host=$host;port=$port",  
                            $username,
                            $password,
                            {AutoCommit => 0, RaiseError => 1}
                         ) or die $DBI::errstr;
