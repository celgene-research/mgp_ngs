package metadataInfo;
use strict;
use warnings;
use adaptors::Solr;
use XML::Simple;
use File::Spec;
use Celgene::Utils::ArrayFunc;
use Data::Dumper;;
my $logger=Log::Log4perl->get_logger("metadataiInfo");



{my $solr;
sub getDatabaseConnection{
	
	my $server='10.130.5.63'; if (defined($ENV{SOLR_IP})){$server=$ENV{SOLR_IP};};
	my $port=8081; if (defined($ENV{SOLR_PORT})){$port=$ENV{SOLR_PORT}};
	$logger->info("getDatabaseConnection: Connecting to SOLR on http://$server:$port/solr");
	#Checking if the Solr server is reachable or not
	if (!defined($solr) or !$solr->ping()) {
	   $logger->info("getDatabaseConnection: Trying to open a new connection to SOLR");
	   $solr=adaptors::Solr->new("http://$server:$port/solr");
	   if(!$solr->ping()){
	   	$logger->logdie("getDatabaseConnection: Testing the connection was not successful");
	   }
	   $logger->info("getDatabaseConnection: Successfully opened connection to SOLR");
	}else{
		$logger->info("getDatabaseConnection: Connection to SOLR previously established");
	}
	return $solr;
}
}
#Searching Solr Server


# query the OODT database (which stores data in SOLR) and return
# an array of filenames that are associated with the sample_id

sub getFilesBySampleID{
	my ($sample_id, $filetype)=@_;
	$logger->info("getFilesBySampleID: looking for [$sample_id]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'FilePath,MimeTypesHierarchy',
	   wt => 'csv',
	   hl => 'false'

	};
	my $query = { q => 'sample_id:'.$sample_id};
	if(defined($filetype)){ $query.=',MimeTypesHierarchy:'.$filetype };
	
	my $response = $solr->search($params, $query);
        if (! $response) {
           print "\n Error: " . $solr->error->{response};
           exit 1;
        }
	my $results=$response->{'response'};	
	$results=~s/","/\t/g;
	$results=~s/"//g;
	$logger->info("getFilesBySampleID: function found ".Dumper( $results) );

	$logger->info("getFilesBySampleID: function call finished SUCCESSFULLY");
	return $results;
}

sub getSampleIDByFilename{
	my($filename)=@_;
	$logger->info("getSampleIDByFilename: looking for ID for [$filename]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'sample_id',
	   wt => 'xml',
	   hl => 'false',

	};
	my $query1 = { q => 'CAS.ReferenceOriginal:"file:' . $filename .'"'};
	my $results1=_getArrayResults( $solr, $query1, $params);
	my $query2 = { q => 'FilePath:"'.$filename.'"'};
	my $results2=_getArrayResults( $solr, $query2, $params);
	my $results=[];
	@$results=( @$results1, @$results2 );
	if( $filename =~/^\/gpfs\/archive/ ){
		(my $filename2=$filename)=~s%/gpfs/archive%/celgene/archive%; # this will accomodate the soft link that exists in the Celgene GPFS filesystem
		$logger->info("getSampleIDByFilename: Checking for alternative file [$filename2] to accomodate the Celgene soft links");
		my $query3 = { q => 'FilePath:"'.$filename2.'"'};
        	my $results3=_getArrayResults( $solr, $query3, $params);	
		@$results=( @$results, @$results3);
	}
	$logger->info("getSampleIDByFilename: for [$filename] found samples :[",join(",", @$results),"]");
	$logger->info("getSampleIDByFilename: function call finished SUCCESSFULLY");

	

	return Celgene::Utils::ArrayFunc::unique($results);
}



sub getSampleIDByDerivedFrom{
	my($filename)=@_;
	$logger->info("getSampleIDByDerivedFrom: looking for sample of file $filename");
	my $derivedFrom=getDerivedFromByFilename( $filename );
	if(!defined($derivedFrom)){return undef;}
	my @sids=();
	foreach my $f(@$derivedFrom){
		my $sid=getSampleIDByFilename($f);
		if(ref($sid)=~/ARRAY/){
			print Dumper($sid);
			@sids=(@sids,@$sid);
		}
		else{
			print Dumper($sid);
			push @sids, $sid;
		}
	}
	
	@sids=Celgene::Utils::ArrayFunc::unique(\@sids);
	$logger->info("getSampleIDByDerivedFrom: for [$filename] found samples :[",join(",", @sids),"]");
	$logger->info("getSampleIDByDerivedFrom: function call finished SUCCESSFULLY");
	return \@sids; 
}

sub getReferenceInfoByFilename{
	my($filename)=@_;
	$logger->info("getReferenceInfoByFilename: looking for Reference information for [$filename]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'reference_db',
	   wt => 'xml',
	   hl => 'false'
	};
	
	my $query1 = { q => 'CAS.ReferenceOriginal:"file:' . $filename .'"'};
	my $results1=_getArrayResults( $solr, $query1, $params);

	my $query2 = { q => 'FilePath:"' . $filename .'"'};
        my $results2=_getArrayResults( $solr, $query2, $params);
	my $results=[];
	@$results=(@$results1, @$results2);

	$logger->info("getReferenceInfoByFilename: for [$filename] found samples :[",join(",", @$results),"]");
	$logger->info("getReferenceInfoByFilename: function call finished SUCCESSFULLY");
	return Celgene::Utils::ArrayFunc::unique($results);
}



sub getStartEndBySampleID{
	my($sample)=@_;
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'sample_id analysis_task start_execution end_execution generator_string',
	   wt => 'xml',
	   hl => 'false',
	   start=>0,
	   count=>10000,
	   rows=>10000
	};
	
	my $query = { q => "sample_id:$sample"};
	my $response = $solr->search($params, $query);
	if (! $response) {
	   print "\n Error: " . $solr->error->{response};
	   exit 1;
	}
	
	my $xml=XML::Simple->new();
	my $ref=$xml->XMLin( $response->{response} );

	my $results=[];
	my $docs=$ref->{result}->{doc};
	if( ref( $docs )!~/ARRAY/){
		my $t=$docs;
		$docs=[];
		push @$docs, $t;
	}
	foreach my $doc(@$docs){
		if(!defined($doc) or !defined($doc->{arr})){next;}
		my $start=$doc->{arr}->{start_execution}->{str};
		my $end=  $doc->{arr}->{end_execution}->{str};
		my $gen=  $doc->{arr}->{generator_string}->{str};
		my $task= $doc->{arr}->{analysis_task}->{str};
		push @$results, [  $sample, $start, $end, $gen, $task] ;
	}
	
	return ($results);
}


sub getDescendantsID{
	my ($filename)=@_;
	$logger->info("getDescendantsID: looking for files coming from  [$filename]");
	my $solr=getDatabaseConnection();
	my $params = {	
		fl => 'ID',
		wt => 'xml',
		hl => 'false',
	};
	my $query1 = { q => 'derived_from:"' . $filename .'"'};
	my $results1=_getArrayResults( $solr, $query1, $params);
	$logger->info("getDescendants: for [$filename] found document id(s) :[",join(",", @$results1),"]");
	$logger->info("getReferenceInfoByFilename: function call finished SUCCESSFULLY");
	return Celgene::Utils::ArrayFunc::unique($results1);

}


sub getDerivedFromByFilename{
	my($filename)=@_;
	$logger->info("getDerivedFromByFilename: looking for 'derived_from' information for [$filename]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'derived_from',
	   wt => 'xml',
	   hl => 'false',

	};

	my $query1 = { q => 'CAS.ReferenceOriginal:"file:' . $filename .'"'};
        my $results1=_getArrayResults( $solr, $query1, $params);

        my $query2 = { q => 'FilePath:"' . $filename .'"'};
        my $results2=_getArrayResults( $solr, $query2, $params);
        my $results=[];
        @$results=(@$results1, @$results2);

	$logger->info("getReferenceInfoByFilename: for [$filename] found samples :[",join(",", @$results),"]");
	$logger->info("getReferenceInfoByFilename: function call finished SUCCESSFULLY");
	return Celgene::Utils::ArrayFunc::unique($results);
}

# get the unique id of a document in SOLR
sub getSOLRIDByFilename{
	my($filename)=@_;
	$logger->info("getSOLRIDByFilename: looking for ID for [$filename]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => 'id',
	   wt => 'xml',
	   hl => 'false',

	};
	my $query1 = { q => 'CAS.ReferenceOriginal:"file:' . $filename .'"'				
	};
	$logger->info("getSOLRIDByFilename: querying database qith $query1->{q}");
	my $results1=_getArrayResults( $solr, $query1, $params);
	
	my $query2 = { q => 'FilePath:"' . $filename .'"'	};
	$logger->info("getSOLRIDByFilename: querying database qith $query2->{q}");
	my $results2=_getArrayResults( $solr, $query2, $params);
	my $results;
	@$results=(@$results1, @$results2);
	
	$logger->info("getSOLRIDByFilename: for [$filename] found document id(s) :[",join(",", @$results),"]");
	$logger->info("getSOLRIDByFilename: function call finished SUCCESSFULLY");
	return Celgene::Utils::ArrayFunc::unique($results);
}

sub getFieldBySOLRID{
	my($field,$solr_id)=@_;
	$logger->info("getFieldBySOLRID: looking for [$field] of [$solr_id]");
	my $solr=getDatabaseConnection();
	my $params = {
	   fl => $field,
	   wt => 'xml',
	   hl => 'false',

	};
	my $query = { q => "id:$solr_id"	
	};
	$logger->info("getFieldBySOLRID: querying database qith $query->{q}");
	my $results=_getArrayResults( $solr, $query, $params);
	$logger->info("getFieldBySOLRID: for document_id=[$solr_id] found $field values :\n[",join("\n\t", @$results),"]");
	$logger->info("getFieldBySOLRID: function call finished SUCCESSFULLY");
	return Celgene::Utils::ArrayFunc::unique($results);
}


sub updateFieldBySOLRID{
	my($field,$value,$solr_id)=@_;
	$logger->info("updateFieldBySOLRID: Attempt to update field [$field]  with value [$value] for document [$solr_id].");
	my $doc=[
		{ 	id => $solr_id,
			$field=>$value
		}
	];
	my $solr=getDatabaseConnection();
	# get the existing FilePath for the this id
	my $results=getFieldBySOLRID( $field, $solr_id );
	$logger->trace("updateFieldBySOLRID: Checking if [$field] already contains [$value] in database for [$solr_id]");
	foreach my $fp( @$results){ 
		$logger->trace("   [$field] in db : $fp\n compare to: $value");
		
		if($fp eq $value or $fp eq "\"$value\"" or $fp eq "'$value'"){ 
			$logger->trace("updateFieldBySOLRID: [$value] exists in the database");
			return 1;
		}
	}
	if( !$solr->update( $doc, $field )){
		$logger->warn("updateFieldBySOLRID: failed to update document [$solr_id] field:[$field] with value:[$value]");
		$logger->warn( $solr->error->{response} );
		return 0;
	}else{
		$logger->info("updateFieldBySOLRID: function call finished SUCCESSFULLY");
		$solr->commit();
	}
	return 1;
}

sub _getArrayResults{
	my ($solr,$query,$params)=@_;
	
	my $response = $solr->search($params, $query);
	if (! $response) {
	   print "\n Error: " . $solr->error->{response};
	   exit 1;
	}

	my $xml=XML::Simple->new();
	my $ref=$xml->XMLin( $response->{response} );
	$logger->trace("_getArrayResults: Ref XML is:");
	$logger->trace( Dumper($ref) );
	my $results=[];
	my $docs=$ref->{result}->{doc};
	if( ref( $docs )!~/ARRAY/){
		my $t=$docs;
		$docs=[];
		push @$docs, $t;
	}
	$logger->trace("_getArrayResults: Return documents are:");
	$logger->trace( Dumper($docs) );
	foreach my $doc(@$docs){
		if(!defined($doc) ){$logger->warn("No document returned");next;}
		if(defined($doc->{arr}->{str})){
			if(ref($doc->{arr}->{str}) =~/ARRAY/){
				foreach my $str(@{$doc->{arr}->{str}} ){
					$logger->trace( "for doc->arr->str the str value is $str\n");
					push @$results, $str if $str;
				}
			}else{
				my $str =$doc->{arr}->{str};
				if(defined( $str)){
					$logger->trace( "for doc->arr->str the str value is $str\n" );
					push @$results, $str;
				}
			}
		}
		if(defined($doc->{str})){
			my $str=$doc->{str}->{content};
			$logger->trace("for doc->str the str value is $str\n" );
			push @$results, $str;
		}
	}
	my $retVal=Celgene::Utils::ArrayFunc::unique($results);
	$logger->trace("_getArrayResults: Return value is");
	$logger->trace( Dumper($retVal));
	return $retVal;
}

1;


