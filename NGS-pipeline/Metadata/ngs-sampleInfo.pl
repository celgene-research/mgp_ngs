#!/usr/bin/perl -w
# quick script to create or update a task on the server.
use strict;
use Frontier::Client;
use File::Spec;
use Data::Dumper;
use Celgene::Utils::ArrayFunc;
use FindBin;
use Cwd;
use Celgene::Utils::SVNversion;
use Getopt::Long;
use Log::Log4perl;

my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-09-16 14:31:45 -0700 (Wed, 16 Sep 2015) $ $Revision: 1645 $ by $Author: kmavrommatis $' );

my($help,$log_level,$log_file,$showversion);
GetOptions(
	"h|help!"=>\$help,
	"loglevel=s"=>\$log_level,
	"logfile=s"=>\$log_file,
	"version!"=>\$showversion
);

if(defined($showversion)){
	print "ngs-sampleInfo.pl $version\n";
	exit 0;
}
my %supportedFields =( 'stranded'=>1,
						'sample_id'=>1,
						'xenograft'=>1,
						'reference_genome'=>1,
						'host_genome'=>1,
						'sequence_kit'=>1,
						'experiment_prep_method'=>1,
						'bait_set'=>1,
						'paired_end'=>1,
						'library_prep'=>1,
						'experiment_type'=>1,
						'technology'=>1,
						'display_name'=>1,
						'antibody_target'=>1
			);
			
			
if(defined($help)){printHelp();exit(0);}

sub printHelp{
	print "
ngs-sampleInfo.pl v ". $version ." 

is a simple script to extract single values from the NGS database.
Usage
ngs-sampleInfo.pl [options] <filename> <field>

filename: the name of the file that needs to be searched in the database
field   : a database field. Currently supported fields are
". join("\n\t", keys(%supportedFields)),"

options are:
 -h | --help get help for the script
 -loglevel/-logfile standard logger options
 -version get the version of the script and exit




 ngs-sampleInfo.pl is a simple script that retrieves sample related data from the NGS database
 It starts with the file, converts the filename to its absolute path (keep in mind that this resolves
 symbolic links), and then queries the OODT database for the sample_id of the file. Subsequently, using
 the sample_id retrieves the metadata of the sample (e.g. experiment type, library etc)
 Its intented use is to be included in longer scripts that need to adjust their function according to
 the type of sample that is being processed
 This script is NOT intented to act as an entry point to the NGS database for getting bulk data, although
 it may evolve to serve this function in the future
 \n";
}

if(defined($showversion)){
	print "ngs-sampleInfo.pl ".$version."\n";
	exit(0);
}

my $logger=setUpLog();

my($filename, $field)=@ARGV;

if(!defined($filename) ) {
	$logger->logdie( "Please provide filename");
}
if(!defined($field)) {
	$logger->logdie( "Please provide field");
}
if(!defined($supportedFields{ $field })) {
	$logger->logdie( "Unsupported field $field");
}


$filename=getAbsPath( $filename );
$logger->debug( "Getting sample information for file $filename\n");
my $server_url = $ENV{ NGS_SERVER_URL };
my $server = Frontier::Client->new('url' => $server_url.'/RPC2');
#print "Connecting to server $server_url\n";


if($field eq 'bait_set'){
	$field='exome_bait_set_name';
}

my $idArray = $server->call('metadataInfo.getSampleIDByFilename',$filename);
$logger->trace(Dumper($idArray));
my @retVals;
foreach my $id ( @{$idArray}){
	
	$logger->debug( "Found sample $id corresponding to file\n");
	if(defined($id)){
		$logger->trace("Getting data for id:$id");
		my $data=$server->call('sampleInfo.getSampleByID', $id);
		$logger->trace(Dumper( $data ));
		if(!defined( $data ) or $data eq ''){next;}
		my $retVal= $data->{ $field };
		$retVal =~s/\s/_/g;
		push @retVals, $retVal;
	}
	
}	
if(scalar(@retVals)==0){print 'NA';}
else{
	@retVals=Celgene::Utils::ArrayFunc::unique(\@retVals);
}
if(scalar(@retVals)>1){ print join(" ", @retVals);}
else{ print $retVals[0]}


exit(0);

sub getAbsPath{
	my($fn)=@_;
	if($fn =~/^s3:/){ return $fn;} # file is a S3 object and is absolute
	if($fn =~/^\//){return $fn;} # file is an absolute filename
	if(! -e $fn){ $logger->logdie("File $fn does not exist");}
	my $retval=Cwd::abs_path($fn);
	return $retval;
	
}


sub setUpLog{
	my ($logLevel,$logFile)=("INFO","$ENV{HOME}/ngs-sampleInfo.log");
	if(defined($log_file)){$logFile=$log_file}
	if(defined($log_level)){$logLevel=$log_level}
	my $logConf=qq{
		log4perl.rootLogger          = $logLevel, Logfile
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
	
	
	my $logger=Log::Log4perl->get_logger("ngs-sampleInfo");
	return $logger;
}