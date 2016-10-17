#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl;
use FindBin;
use Getopt::Long;
use lib $FindBin::RealBin;
use lib $FindBin::RealBin."/lib/";
#use DatabaseFunc;
use fastQCsteps;
use File::Spec;
use File::Basename;
use Celgene::Utils::SVNversion;
use Celgene::Utils::ArrayFunc;
use Frontier::Client;
use Sys::Hostname;
use Data::Dumper;
my $host=hostname;
my $arguments=join(" ",@ARGV);
#my $annotationFile="/opt/reference/Homo_sapiens/GENCODE/hg19/Annotation/gencode.v14.refFlat"; # for ENSEMBL
my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-10-14 08:34:44 -0700 (Wed, 14 Oct 2015) $ $Revision: 1707 $' );
my ($logLevel,$logFile,$manifest,$help,$inputFQ,$inputBAM,$usersample_id,$nocommit,$reuse, $mapper)=('INFO',undef,undef);
my($ribosomal_intervals,$annotationFile,$strand,$genomeFile,$qcStep,$outputFile,$sampleFlag,$compatibility);
GetOptions(
	"loglevel=s"=>\$logLevel,
	"logfile=s"=>\$logFile,
	"qcfile=s"=>\$outputFile,
	"reuse!"=>\$reuse,
	"outputfile=s"=>\$compatibility,
	"inputfq=s"=>\$inputFQ,
	"sample_id=s"=>\$usersample_id,
	"sample_flag=s"=>\$sampleFlag,
	"nocommit"=>\$nocommit,
	"qcStep=s"=>\$qcStep,
	"help"=>\$help
);
if(!defined($logFile)){
	if(defined($usersample_id)){$logFile= $usersample_id.".log";}
	else{$logFile = "runQC.log";}
}

#outputfile is an option that is not use any more, but kept for compatibility
if(defined($compatibility)) { $outputFile=$compatibility;}

sub printHelp{
	print
	"$0. $version program that drives the QC analysis of samples\n".
	"arguments\n".
	" --sample_id <sample id of the file> (script will try to find it from the filename)\n".
	" --qcfile <file to store QC output>. The contents of this file will be automatically added to the database\n".
	" --sample_flag a flag the defines the type of sample information to store 
	('original' : for the standard information [default]
	 'trimmed'  : for Qc on reads after trimming)".
	" --qcStep define QC module to run ('FastQC','LaneDistribution','Adapter')\n".
	" --nocommit will not update the database\n".
	" --logLevel/--logFile standard logger arguments\n".
	" --help this screen\n".
	"\n\n";
}


my $port=8082;
if(defined($ENV{NGS_SERVER_PORT})){ 
	$port= $ENV{NGS_SERVER_PORT};
}
my $ip="localhost";
if(defined($ENV{NGS_SERVER_IP})){ 
	$ip= $ENV{NGS_SERVER_IP};
}
my $server_url = "http://".$ip.":".$port."/RPC2";
my $server = Frontier::Client->new('url' => $server_url);


# this script is used to initiate the local QC process on a set 
# of fastq and bam files that correspond to ONE sample only


my $logConf=qq{
		log4perl.rootLogger          = $logLevel, Logfile,Screen
	    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
	    log4perl.appender.Logfile.filename = $logFile
	    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
	    log4perl.appender.Logfile.layout.ConversionPattern = [%p : %c - %d] - %m{chomp}%n
	    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
	    log4perl.appender.Screen.stderr  = 0
	    log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
	    log4perl.appender.Screen.layout.ConversionPattern = [%p : %c - %d] - %m{chomp}%n
};
Log::Log4perl->init(\$logConf);
my $logger=Log::Log4perl->get_logger("runQC");


if(!defined($outputFile)){
	printHelp();
	$logger->logdie("Please provide the name of the qcstats file (qcfile)");
}

$logger->info("Connecting to server $server_url");




$logger->info("$0 ($version).");
$logger->info("Host: $host");
$logger->info("Arguments $arguments");


   
if( !defined($sampleFlag)){ $sampleFlag='original'}
 
my $sample_id;
if(!defined($usersample_id)){
	$logger->info("Getting the sample id from the file $outputFile");
	$sample_id=getsampleid( $outputFile,$sampleFlag );
	if( (!defined($sample_id )or $sample_id eq 'NA') and defined($inputFQ)){
		my @a=split(",",$inputFQ);
		$logger->info("Getting the sample id from the file $a[0]");
		my $s1=getsampleid( $a[0],$sampleFlag);
		my $s2;
		if(scalar(@a)>1){ 
			$logger->info("Getting the sample id from the file $a[1]");
			$s2=getsampleid( $a[1],$sampleFlag);
		}
		if(!defined($s2)){$s2=$s1;}
		if($s1 ne 'NA' ){
			$sample_id=$s1
		}else{ 
			$sample_id=$s2;
		}
	}
	
	
	if(!defined($sample_id) or $sample_id eq 'NA'){ $logger->logdie("Neither a sample id was provided nor was it possible to get from the name of the qc file ($outputFile)");}
	}else{
		$sample_id=$usersample_id;
	}   
	
my($name, $inlist)=( $sample_id, $inputFQ);
$logger->info("Processing fastq: $inlist") if(defined($inlist));


my $fastQC=fastQCsteps->new();
my $binary=`which fastqc`; chomp $binary;
$logger->info("Found fastqc at [$binary]");
$fastQC->binary($binary );
my $binary2=`which cutadapt`; chomp $binary2;
$logger->info("Found cutadapt at [$binary2]");
$fastQC->binaryTrimmer($binary2);
my $binary3=`which getLibraryDistribution.pl`; chomp $binary3;
$logger->info("Found getLibraryDistribution.pl at [$binary3]");
$fastQC->binaryLaneDistribution( $binary3 );
$fastQC->outputFile($outputFile );
#$fastQC->technology( $technology );
$fastQC->reuse();
my($fq1,$fq2)=split('null','null');
$fastQC->runFastqQC($fq1, $fq2,$qcStep);
$fastQC->parseFile( $fq1, $fq2, $qcStep);

if($qcStep eq 'FastQC'){
	my $fqc=processFastQC( $fastQC );

#	print Dumper($fqc);

	getFromXMLserver("sampleQC.updateReadQC", $fqc,$sample_id, $sampleFlag);
}
if($qcStep eq 'LaneDistribution'){
	my $fqc=processLane( $fastQC );
	getFromXMLserver("sampleQC.updateReadQC", $fqc,$sample_id, $sampleFlag);
}
if($qcStep eq 'Adapter'){
	my $fqc=processAdapter( $fastQC );
	print Dumper($fqc);
	getFromXMLserver("sampleQC.updateReadQC", $fqc,$sample_id, $sampleFlag);
}



$logger->info("Updating database entry for sample $sample_id");

	


$logger->info("Processing finished successfully");

sub processFastQC{
	my($fastQC)=@_;
	return {
		'N' => $fastQC->{N},
		'median' =>  $fastQC->{median},
		'GC' =>  $fastQC->{GC},
		'encoding' =>  $fastQC->{encoding}->[0],
		'totalsequences' =>  $fastQC->{totalsequences},
		'lowerquartile' =>  $fastQC->{lowerquartile},
		'mean' =>  $fastQC->{mean},
		'sequencelength' =>  $fastQC->{sequencelength}->[0],
		'upperquartile' =>  $fastQC->{upperquartile},
		'tenpercentile' =>  $fastQC->{tenpercentile},
		'ninetypercentile' =>  $fastQC->{ninetypercentile}
	};
	
}
sub processAdapter{
	my($fastQC)=@_;
	return {
		'too_short_reads' => $fastQC->{too_short_reads},
		'too_long_reads' =>  $fastQC->{too_long_reads},
		'trimmed_reads' =>  $fastQC->{trimmed_reads},
		'trimmed_expected' =>  $fastQC->{trimmed_expected},
		'trimmed_length' =>  $fastQC->{trimmed_length},
		'trimmed_bases' =>  $fastQC->{trimmed_bases},
		'trimmed_count' =>  $fastQC->{trimmed_count},
		'trimming_events' =>  $fastQC->{trimming_events},
		'adapter' =>  $fastQC->{adapter},
		'quality_trimmed_bases'=> $fastQC->{quality_trimmed_bases}
		
	};
	
}

sub processLane{
	my($fastQC)=@_;
	return {
		'lanes_reads' =>  $fastQC->{lanes_reads},
		'lanes' =>  $fastQC->{lanes}
	};
	
}

sub getsampleid{
	my ($fastqfile, $flag)=@_;
	my($is_paired_end,$is_stranded,$technology)=(undef,undef,undef);
	my ($sql,$cur,$sample_id);
	# get the sample id from the  metadata
	# for this to work we need to make sure that each file has only one sample_id
	my @irodsSampleID;my @t1;my @t2;
	if(defined($fastqfile)){
		my @fq=split(",",$fastqfile);
		foreach my $fq(@fq){
			$fq=File::Spec->rel2abs( $fq );
			my $t=getFromXMLserver('metadataInfo.getSampleIDByFilename',$fq);
			@t1=(@t1,@$t);
			
			$logger->trace("The sample id(s) for the file $fq is ". Dumper(@irodsSampleID));
		}
	}
	
	@irodsSampleID=(@t1,@t2);
	@irodsSampleID=Celgene::Utils::ArrayFunc::unique( \@irodsSampleID );
	if(scalar(@irodsSampleID) >1){
		$logger->logdie("Cannot assign file $fastqfile to multiple samples (got ",join(",",@irodsSampleID),")");
	}
	elsif(scalar(@irodsSampleID)==0){ #This file is not registred in irods
		$logger->warn("File $fastqfile is not register to metadata or don't have sample information");
		return undef;
	}else{
		$sample_id= $irodsSampleID[0];
		$logger->debug("From file metadata the sample was found to be $sample_id");
		
	}
	
	$logger->info("Retrieving information for sample $sample_id");
	# check if the sample exists in sample_sequencing
	if(defined($fastqfile)){
		my $result=getFromXMLserver('sampleInfo.getSampleFastQCByID', $sample_id,$flag);
		if( $result eq ""){
			$logger->info("Inserting entry for $sample_id in table sample_readqc");
			my %h=('sample_id'=>$sample_id);
			getFromXMLserver('sampleInfo.createSampleFastQC', \%h,$flag);
			$result=getFromXMLserver('sampleInfo.getSampleFastQCByID', $sample_id,$flag);
		}
		
		my($check_id,$mr,$sr,$tech)=($result->{sample_id}, $result->{mate_reads},$result->{stranded},$result->{technology});

		$is_paired_end=$mr;
		$is_stranded=$sr;
		$technology=$tech;
		$logger->trace( Dumper($result));	
	}
	print "paired: $is_paired_end, stranded: $is_stranded\n";
#	$dbh->disconnect();

 #is_paired_end can be either true or false
	if(defined($is_paired_end) and ($is_paired_end eq '0' or $is_paired_end eq 'no')){$is_paired_end='false';}
	if(defined($is_paired_end) and ($is_paired_end eq '1' or $is_paired_end eq 'yes')){$is_paired_end='true';}
# is_stranded can be 'NONE'i.e. not stranded  'CONVERGE' i.e. two reads pointing to each other 'DIVERGE'i.e. two reads pointing outside

	if(!defined($is_stranded)){$is_stranded='undef';}
	if(!defined($is_paired_end)){$is_paired_end='undef';}
	$logger->info("Is paired end: $is_paired_end");
	$logger->info("Is stranded: $is_stranded");
	#return ($sample_id, $is_paired_end,$is_stranded,$technology);
	return($sample_id);
}


sub getFromXMLserver{
	my(@args)=@_;
	my $retArray;
	my $result;
	my $retries = 10;
	for(my $r=1; $r<= $retries; $r++){
		$retArray=eval{$server->call( @args ); } ;
		
		if($@){
			$logger->warn("getFromXMLserver: Attempt $r to connect server failed with error [$@]");
			
			if( $r==$retries){
				$logger->logdie("getFromXMLserver: Cannot contact server. Aborting !!!")
			}
			
		}else{
			if($r>1){
                $logger->info("getFromXMLserver: Attempt $r/$retries was successful");
            }else{
            	$logger->info("getFromXMLserver: Data retrieval from server was successful");
            }
            
            last;
			
		}
	}
	#while( 1 ){
	#	$result = $server->call( @args );
		
	#	$logger->warn("Got bad response from server [$result]. Retrying in 2 seconds");
	#	sleep(2);
	#}
	return $retArray;
}
