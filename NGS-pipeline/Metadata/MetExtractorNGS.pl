#!/usr/bin/env perl

use strict;
use FindBin;
use lib $FindBin::RealBin;
use lib $FindBin::RealBin."/lib";
use File::Basename;
use Sys::Hostname;
use configParser;
use metadataFunc;
use Log::Log4perl;
use MetadataPrepare;
use Frontier::Client;
use Celgene::Utils::ArrayFunc;
use File::Spec;
use Cwd;
use Data::Dumper;
my $filehost=hostname;

# if the .met file contains sample_id information typically this program will
# keep it and append with additional information coming from the derived_from files
my $ignoreExistingSample_id;
# if the user sets the ENV variable 'IGNORE_MET_SAMPLEID' then the script will 
# strip off existing sample_id information
if(defined($ENV{ 'IGNORE_MET_SAMPLEID' })){ $ignoreExistingSample_id=1;}
my $NGS_LOG_DIR=$ENV{NGS_LOG_DIR};
if(!defined($NGS_LOG_DIR)){$NGS_LOG_DIR= $FindBin::RealBin;}
my ($logLevel,$logFile)=("FATAL",$NGS_LOG_DIR."/ExtractMetadata-${filehost}.log");
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
my $logger=Log::Log4perl->get_logger("MetExtractorNGS");
my($inputFn,$filetype)=@ARGV;
my $output= $inputFn.".met";
my $configuration=configParser->new();
# initiate a metadata object
my $oodt=MetadataPrepare->new();

# load from the oodt file if exists
if(-e $output){ 
	$logger->debug("Appending to file $output");
	$oodt->loadFileOODT($output);
}

# ignore the .met files
if($inputFn =~/.met$/){ 
	$logger->warn("Input file $inputFn will be ignored. .met files are not processed !");
	exit(0);
}

my $ingestUser= $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);

if(defined($ignoreExistingSample_id)){
	$oodt->clearMetadata('sample_id');
	$oodt->clearMetadata('FilePath');
}
$oodt->addMetadata('file_host',$filehost);
$oodt->addMetadata('ProductType','GenericFile');
$oodt->addMetadata('ingest_user',$ingestUser);
my $fpath=getAbsPath($inputFn);


if($configuration->{fileregex}){
	my @frpath;
	$logger->debug("Fileregex has been defined in the config file");
	
	foreach my $fn ( @$fpath){
		foreach my $source( keys  %{$configuration->{ fileregex }}){
			my $target= $configuration->{ fileregex }->{ $source };
			$logger->debug("Based on fileregex we convert $source to $target");
			my $ttt=$fn;
			$ttt=~s|$source|$target|;
			if($ttt eq $fn){next;}
			$logger->debug("Converting \n\t$fn to \t$ttt");
			
			push @frpath, $ttt;
		}
	}
	@$fpath=(@$fpath, @frpath);
}

$logger->debug("The file path is \n". join("\n",@$fpath). ". It will be added under the FilePath metadata field");


$oodt->addMetadata('FilePath', $fpath );


my $server = metadataFunc::getServer();
my $derivedFrom=$oodt->getMetadata( 'derived_from');
foreach my $d(@$derivedFrom){
			
	$logger->debug("Getting information from the derived_from file(s) $d");
	my $darray=getAbsPath($d);
	my $sample_id=[];
	my $reference_db=[];
	foreach my $dfile (@{$darray}){
	$logger->debug("Getting information for the derived_from file $dfile");
		my $sampleId = metadataFunc::serverCall('metadataInfo.getSampleIDByFilename', $dfile);
		@{$sample_id}=( @$sample_id, @$sampleId) if (defined($sampleId) and scalar(@$sampleId)>0);
		my $referenceDB = metadataFunc::serverCall('metadataInfo.getReferenceInfoByFilename', $dfile);
		if(!defined($referenceDB)){
			my($v,$d2,$f)=File::Spec->splitpath($dfile);
			$referenceDB=metadataFunc::serverCall('metadataInfo.getReferenceInfoByFilename', $d2);
		
		}
		@{$reference_db}= (@$reference_db, @$referenceDB) if( defined($referenceDB) and scalar(@$referenceDB) >0);
	}
	$sample_id=Celgene::Utils::ArrayFunc::unique( $sample_id );
	$reference_db=Celgene::Utils::ArrayFunc::unique( $reference_db );
	if(defined($sample_id) and scalar(@$sample_id)>0){
		$oodt->addMetadata('sample_id', $sample_id);
		$logger->debug("Found sample_id =[", join(",",@$sample_id),"] from $d");
		#print Dumper ($sampleId);
	}else{
		$logger->warn("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
		$logger->warn("$inputFn: Could not find sample_id from $d");
		$logger->warn("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
	}
	$logger->debug("Checking if derived_from is a reference database");
	# sometimes the information for the reference database is not on the file but on the directory
	if(defined($reference_db) and scalar(@$reference_db) > 0 ){
		$oodt->addMetadata('reference_db', $reference_db);
		$logger->debug("Found reference db [", join(",",@$reference_db),"]");
	}
}


sub getAbsPath{
	my($fn)=@_;
	my $retval=[];
	if($fn =~/^s3/){ push @{$retval}, $fn; return $retval; }
	my $retval1=Cwd::realpath( $fn );
	push @{$retval}, $retval1;
	my $retval2=File::Spec->rel2abs($fn);
	if($retval1 ne $retval2){
		push @{$retval} , $retval2
	}
	return $retval;
}


# get metadata for specific filetypes.
if(defined($filetype) ){
	$logger->debug("This file is of type $filetype");
	if($filetype eq 'bam'){
		$logger->debug("This file will be processed to extract metadata");
		my $line=` samtools view -H $inputFn | grep 'SO:'`;
		chomp $line;
		$logger->debug("Bam header contains [$line]");
		if($line =~/queryname/){ $oodt->addMetadata('AlignmentSort', 'querynamesorted')}
		elsif($line =~/coordinate/){ $oodt->addMetadata('AlignmentSort', 'coordinatesorted')}
		else{ $oodt->addMetadata('AlignmentSort','notsorted')}
	}
}


# store the metadata
$logger->debug("Storing metadata in file $output");
$oodt->storeOODT( $output );
$logger->debug("Process finished SUCCESSFULLY");

exit(0);
