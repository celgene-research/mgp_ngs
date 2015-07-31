package Celgene::Utils::DatabaseFunc;
use DBI;
use strict;
use warnings;
use  Log::Log4perl;
my $dbh;
my $logger=Log::Log4perl->get_logger("DatabaseFunc");

sub connectDB{
	my $hostIP=$ENV{ NGS_SERVER_IP }	;
	if(!defined($dbh)){
		$logger->info("connectDB: Connecting to database for the first time");
		$dbh = DBI->connect("DBI:Pg:dbname=genomics;host=$hostIP", "kostas", "kostas", {'RaiseError' => 1}  );
	}elsif($dbh->ping == 0){
		$logger->info("connectDB: Connection was dropped. Reconnecting to the database");
		$dbh = DBI->connect("DBI:Pg:dbname=genomics;host=$hostIP", "kostas", "kostas", {'RaiseError' => 1}  );
	}else{
		$logger->info("connectDB: Connection to database is already established");	
	}
	return $dbh;
}

sub disconnectDB{
	$logger->info("disconnectDB: Explicit request to disconnect from the database");
	$dbh->disconnect();
}


1;
