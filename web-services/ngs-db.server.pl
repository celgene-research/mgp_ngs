#!/usr/bin/perl -w
# getSampleByID: returns the full row of data in the database for a given sample_id
# TODO
# getSampleByCelgeneID: returns the full row of data in the database for a given celgene sample_id
# get QC parameters (either one by one or as a total)
# get analysis tasks


# create analysis task



use strict;
use Frontier::Daemon;
use Celgene::Utils::DatabaseFunc;
use Log::Log4perl;
use Socket;
use Sys::Hostname;
use FindBin qw($RealBin);
use sampleInfo;
use metadataInfo;
use analysisTaskInfo;
use Getopt::Long;

my($logLevel,$logFile,$ip,$help, $stop, $restart);
GetOptions(
	"loglevel=s"=>\$logLevel,
	"logfile=s"=>\$logFile,
	"forcePort=s"=>\$ip,
	"stop!"=>\$stop,
	"restart!"=>\$restart,
	"help"=>\$help
);

if(defined($help)){
	printUsage();
	exit(0);
}


if( defined($stop)){ my $pid=getPID(); kill 'KILL', $pid; exit(0);} 
if( defined($restart)){  my $pid=getPID(); kill 'KILL', $pid; }
storePID();

sub getPID{
	open(my $rfh, "ngs-server.pid") or die "Cannot read file ngs-server.pid\n";
	my $pid=<$rfh>;
	chomp $pid;
	close($rfh);
	return $pid;
}
sub storePID{
	my $pid=$$;
	open(my $wfh, ">ngs-server.pid") or die "Cannot create file ngs-server.pid\n";
	print $wfh $pid,"\n";
	close( $wfh );
}
sub printUsage{
	print
	"$0. XML-RPC server application that provides access to the metadata and sample information database\n".
	"--logLevel/logFile\n".
	"--stop/restart stops or restarts the server. Assumes pid that is stored in the file ngs-server.pid\n".
	"--forcePort force to use a different port than the default [8082]\n".
	"--help this page\n";
}

# list of available functions and what they do:
if(!defined($logFile)){ $logFile=$RealBin."/ngs-db.log";}
if(!defined($logLevel)){$logLevel="INFO";}
my $logger=setupLog();
no warnings 'uninitialized';

sub getGeneAnnotation{
	
	my ($gene_name,$dbhParam)=@_;
		my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("getGeneAnnotation: Connecting to database");
	my $sql=qq{
		select distinct( go.gene_description ) as go_gene_description
		from genomes.go go
		where go.gene_name='$gene_name'
	};
	$logger->info("getGeneAnnotation: Executing $sql");
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $result=$cur->fetchrow_hashref();
	$cur->finish();
	
	if(!defined($dbhParam)){
		$dbh->disconnect();
	}

	return $result;	
	
}

sub setupLog{
my $logConf=qq{
	log4perl.rootLogger          = $logLevel, Logfile, Screen
    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = $logFile
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%p : %c - %d] - %m{chomp}%n
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = [%p - %d] - %m{chomp}%n
};
Log::Log4perl->init(\$logConf);
my $logger=Log::Log4perl->get_logger("NGS-db Server");
return $logger;
}

# Call me as http://localhost:8080/RPC2


my $methods = {	
				'alive'=>\&alive,
				'sampleInfo.getSampleByID' => \&sampleInfo::getSampleByID,
				'sampleInfo.getSampleByName'=>\&sampleInfo::getSampleByName,
				'sampleInfo.getSampleByVendorID'=>\&sampleInfo::getSampleByVendorID,
				'sampleInfo.createSample'=>\&sampleInfo::createSample,
				'sampleInfo.getTableCV'	=> \&sampleInfo::getTableCV,
				'sampleInfo.enterCV'=>\&sampleInfo::enterCV,
				'sampleInfo.getProjectByName'=>\&sampleInfo::getProjectByName,
				'sampleInfo.getOrCreateProjectByName'=>\&sampleInfo::getOrCreateProjectByName,
				'sampleInfo.getSampleFastQCByID'=>\&sampleInfo::getSampleFastQCByID,
				'sampleInfo.getSampleExperimentByID'=>\&sampleInfo::getSampleExperimentByID,
				'sampleInfo.createSampleFastQC'=>\&sampleInfo::createSampleFastQC,
				'sampleInfo.getSampleBamQCByID'=>\&sampleInfo::getSampleBamQCByID,
				'sampleInfo.createSampleBamQC'=>\&sampleInfo::createSampleBamQC,
				'sampleInfo.getOmicSoftTable'=>\&sampleInfo::getOmicSoftTable,
				'sampleInfo.getSampleListByProjectName'=>\&sampleInfo::getSampleListByProjectName,
				'sampleInfo.createProjectSynonyms'=>\&sampleInfo::createProjectSynonyms,
				
				'sampleQC.updateReadQC'=>\&sampleInfo::updateReadQC,
				'sampleQC.updateAlignmentQC'=>\&sampleInfo::updateAlignmentQC,
				'sampleQC.getQCReportTable'=>\&sampleInfo::getQCReportTable,		
		

				'metadataInfo.getDescendantsID'=>\&metadataInfo::getDescendantsID,
				'metadataInfo.getDerivedFromByFilename'=>\&metadataInfo::getDerivedFromByFilename,
				'metadataInfo.getSampleIDByDerivedFrom'=>\&metadataInfo::getSampleIDByDerivedFrom,
				'metadataInfo.getFilesBySampleID'=>\&metadataInfo::getFilesBySampleID,
				'metadataInfo.getSampleIDByFilename'=>\&metadataInfo::getSampleIDByFilename,
				'metadataInfo.getReferenceInfoByFilename'=>\&metadataInfo::getReferenceInfoByFilename,
				'metadataInfo.getSOLRIDByFilename'=>\&metadataInfo::getSOLRIDByFilename,
				'metadataInfo.updateFieldBySOLRID'=>\&metadataInfo::updateFieldBySOLRID,
				'metadataInfo.getFieldBySOLRID'=>\&metadataInfo::getFieldBySOLRID,
				'analysisTaskInfo.createNewTask'=>\&analysisTaskInfo::createNewTask,
				'analysisTaskInfo.updateTask'=>\&analysisTaskInfo::updateTask,
			 	
			 	'geneInfo.getGeneAnnotation'=>\&getGeneAnnotation};
			 	

my $port=8082;
if(defined($ip)){$port=$ip}
elsif(defined($ENV{NGS_SERVER_PORT})){ 
	$port= $ENV{NGS_SERVER_PORT};
}

my $host=hostname;
my @addresses = gethostbyname($host);
my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses];

sub alive{
	# function to indicate that the server is alive
	
	$logger->info("Received alive request");
	return("server is alive (http://$ip:$port/RPC2)");
	
	
}



$logger->info("You can access the ngs server at");
$logger->info("http://".$ips[0].":".$port);

Frontier::Daemon->new(
	LocalPort => $port, 
	methods => $methods,
	Listen=>2000,
	#ReuseAddr=>1,
	ReusePort=>1
	)
    or die "Couldn't start HTTP server: $!";