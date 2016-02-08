package metadataFunc;
use Exporter;
@ISA = qw(Exporter);
@EXPORT=qw( serverCall );
use strict;
use warnings;
use Log::Log4perl;



my $logger=Log::Log4perl->get_logger("metadataFunc");
# A function to receive data and update data to the database (Postgres and SOLR)
our $retries=3;
our $server;

sub getServer{
	my( $server_url)=@_;
	if(!defined($server_url)){
		
		if(!defined($ENV{NGS_SERVER_URL})){
			$logger->logdie("getServer: Cannot find the environment variable \$NGS_SERVER_URL and user did not provide server url");
		}
		
		
		$server_url = $ENV{ NGS_SERVER_URL }."/RPC2";
	}
	$metadataFunc::server = Frontier::Client->new('url' => $server_url);
	$logger->debug("getServer: The server url is set to $server_url");
	return $metadataFunc::server;
}


sub serverCall{
	my ($function, @arguments)=@_;
	my $retArray;
	$logger->debug("serverCall: Retries set to $retries");
	for(my $r=1; $r<= $retries; $r++){
		$retArray=eval{$server->call($function,@arguments); } ;
		
		if($@){
			$logger->warn("serverCall: Attempt $r to connect server failed with error [$@]");
			
			if( $r==$retries){
				$logger->logdie("serverCall: Cannot contact server. Aborting !!!")
			}
			
		}else{
			if($r>1){
                $logger->info("serverCall: Attempt $r/$retries was successful");
            }else{
            	$logger->info("serverCall: Data retrieval from server was successful");
            }
            
            last;
			
		}
	}
	return( $retArray );	
}

1;