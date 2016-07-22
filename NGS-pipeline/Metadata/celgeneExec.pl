#!/usr/bin/env perl
# script to intercept calls to external programs and store appropriate metadata
use strict;
use warnings;
use File::Basename;
use FindBin;
use lib $FindBin::RealBin;
use lib $FindBin::RealBin."/lib";
use Log::Log4perl;
use Celgene::Utils::ArrayFunc;
use Celgene::Utils::FileFunc;
use Celgene::Utils::SVNversion;
#use Time::localtime;
use Sys::Hostname;
use Celgene::Utils::CommonFunc;
use MetadataPrepare;
use celgeneExec;
use celgeneExecPrograms;
use fileObj;
use Getopt::Long;


my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-08-16 22:19:49 -0700 (Sun, 16 Aug 2015) $ $Revision: 1625 $ by $Author: kmavrommatis $' );

my($help,$log_level,$log_file,$analysis_task,$derived_from,$derived_from_file,$showversion,@output_file,$norun,$metadata_string,$ignoreFail);
GetOptions(
	"analysis_task|analysistask|a=s"=>\$analysis_task,
	"h|help!"=>\$help,
	"norun!"=>\$norun,
	"loglevel=s"=>\$log_level,
	"logfile=s"=>\$log_file,
	"ignorefail!"=>\$ignoreFail,
	"derivedfrom|derived_from|d=s"=>\$derived_from,
	"derivedfromfile|derived_from_file|D=s"=>\$derived_from_file,
	"outputfile|output|output_file|o=s"=>\@output_file,
	"metadatastring=s@"=>\$metadata_string,
	"version!"=>\$showversion
);
if(defined($showversion)){
	print "$0 version $version\n";
	exit(0);
}
if(defined($help)){
	printUsage();
	exit 0;
}

#use SVNversion;
my $logger=setUpLog();

if( scalar(@ARGV) ==0){
	printUsage();
	$logger->logdie( "Please provide the command you would like to run\n");
}

my $host=hostname;

# the scripts receives only one input argument, the command to execute
# optionally the first argument can be a comma separated list with information
# about the analysis_task and derived_from_list which are processed independently
#my $analysis_task;my $derivedFrom;
my $hash={};

# get program specific arguments
#if(defined($ARGV[0]) ) { parseArguments( $ARGV[0], $hash); }
# if there are program specific argument clear them from the rest of the command 

if(defined($analysis_task)){ 
	$logger->debug("Analysis task specified to be [$analysis_task]");
	$hash->{analysis_task}= $analysis_task;
}
if(defined($derived_from)){
	$logger->debug("Derived from files are found in file [$derived_from]");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle( $derived_from );
	while(my $l=<$rfh>){ 
		chomp $l; 
		push  @{$hash->{derived_from}}, $l;
	}
	close($rfh);
}


foreach my $mstring(@$metadata_string){
	my $metadataString="";

	my ($mKey,@mFn)=split( "=",$mstring);
	my $mFn=join("=", @mFn); # do this to avoid splitting the value of the metadata string on an '=' sign
	
	if( !defined($mKey ) or !defined($mFn)){
		$logger->logdie("Option [metadatastring] provided but without the correct amount of arguments ($metadata_string)");
	}
	if( -e $mFn){
		$logger->info("Including the metadata field $mKey with the contents of file $mFn");
		my $fh=Celgene::Utils::FileFunc::newReadFileHandle($mFn);
		my @metadataContent= <$fh>;
		close($fh);
		$metadataString=join("", @metadataContent) if scalar(@metadataContent)>0;
	}else{
		$logger->info("Including the metadata field $mKey with the value $mFn");
		$metadataString=$mFn;
	}

	
	$hash->{ $mKey }= $metadataString;
}



#if(defined($hash->{analysis_task}) or defined($hash->{derived_from})){shift @ARGV;}


my $UserCommand=join(" ",@ARGV);
my $originalCommand=$UserCommand;


$logger->info("Submitted command:\n**       $UserCommand");


my @cmds=splitCommand($UserCommand); # split at the pipe symbol
my @possibleFiles=();
foreach my $cmd(@cmds){
	$logger->trace("Parsing command '$cmd'");
	my ($binaryObj, $interpreterObj)=getBinary($cmd); # get the name of the binary (including the interpreter if necessary) Both return as fileOjb
	if(!defined($interpreterObj)){$interpreterObj=fileObj->new("","");} # create a dummy interpreter if there isn't one
	$logger->trace("Setting runcommand ");
	
	my $runCommand=setRunCommand($binaryObj->filename(), $interpreterObj->filename() );
	
	# depending on the binary get the appropriate information
	$logger->debug("Seeking information for binary: $runCommand");
	push @{$hash->{generator}},$binaryObj->onlyFilename();
	
	## get teh list of all possible files mentioned in the command line
	# and replace the command line if some of the objects are URIs
	my $untouchedCmd=$cmd;
	my $candidatesObj=getPossibleFiles(\$cmd, $binaryObj,$interpreterObj);
	
	@possibleFiles=( @possibleFiles, @$candidatesObj);
	
	getVersion( $hash, $binaryObj, $interpreterObj);
	
	parseSpecific( $binaryObj,$interpreterObj,$hash ,\@possibleFiles); # parse information
	$logger->trace("=======================");
	$logger->trace("The original command is $untouchedCmd");
	$logger->trace("The new command became  $cmd");
	$logger->trace("=======================");
	if( $untouchedCmd ne $cmd ){
		$UserCommand =~ s/$untouchedCmd/$cmd/;
	}
}
$hash->{generator_string}="'$originalCommand'"; # this is the full command as provided by the user
$hash->{run_host}=$host; 
$hash->{run_user}=$ENV{USER};



# get the list of possible derived_from files (this includes reference databases as well)

getExistingFiles( \@possibleFiles , $hash, $UserCommand);
foreach my $pf(@possibleFiles){
	$logger->trace( "possible files:", $pf->absFilename(),"]\n");

}

	if(defined($derived_from_file)){
		my @tmpfiles=split(",", $derived_from_file);
		foreach my $tmpfile( @tmpfiles ){
			$logger->debug("Adding in the list of derived from files file : $tmpfile");
			push  @{$hash->{derived_from}}, $tmpfile;	
		}
		
	}
	

if( !defined($hash->{derived_from}) or scalar(@{$hash->{derived_from}})  ==0) {
	$logger->logdie("There are no derived_from files, are you sure you have submitted the correct command line from the correct directory?");
}
$logger->debug("derived_from " , join(",", @{$hash->{derived_from}}),"\n");
# execute the command
# get the current time - time where the command is executed

if(defined($norun)){
	$logger->info("Program will exit because user used the 'norun' command");
	exit(0);
}
my $start=time();
$logger->info("Executing command\n**     $UserCommand");


# tokenize command on the ';' symbol
my @UserCommands=split(";", $UserCommand);

foreach my $u( @UserCommands ){
	if($u eq "" or $u eq " " or $u eq "  "){next;}
	$logger->info("Executing sub command : $u");
	if(defined($norun)){
		$logger->info("The command will not be executed but will try to generate the .met file");
		next;
	}
	
	open( my $fh, '-|', qw(bash -c), $u ) ;
	while(my $l=<$fh>){
		$logger->info("$l");	
	}
	close($fh);
	my $capturedCode=0;
	if ($? == -1) {
		$capturedCode=-1;
	   $logger->warn( "failed to execute: $!\n" );
	}
	elsif ($? & 127) {
	    $logger->warn( sprintf( "child died with signal %d, %s coredump\n",
	    ($? & 127),  ($? & 128) ? 'with' : 'without' ));
	    $capturedCode=127;
	}
	else {
		my $returnCode=$?>>8;
		$capturedCode=$returnCode;
		if($returnCode !=0){
	    	$logger->warn( (sprintf( "child process exited with value %d\n", $returnCode)));
		}else{
			$logger->info("Command executed successfully");
		}
	}
	if($capturedCode != 0 and defined($ignoreFail) ){
		$logger->warn("celgeneExec failed to run the command $u. But execution was continued");
	}elsif($capturedCode != 0 and !defined($ignoreFail) ){
		$logger->warn("celgeneExec failed to run the command $u.");
	}
}

my $end=time();
$hash->{start_execution}=scalar(localtime($start));chomp( $hash->{start_execution});
$hash->{end_execution}=scalar(localtime($end));chomp($hash->{end_execution});

# find the files that are modified after the time the command was run.
if(scalar(@output_file)>0){
	foreach my $o( @output_file){
		my $outputObj=fileObj->new( $o, "regular");
		$logger->debug("Adding $o in the list of possible files");
		push @possibleFiles, $outputObj
	}
}
getNewFiles(\@possibleFiles, $hash, $start);
@{$hash->{output}}=Celgene::Utils::ArrayFunc::unique($hash->{output});



if(scalar(@{$hash->{output}})  ==0){
	$logger->warn("There are no output files, are you sure you have submitted the correct command ?");
}

$logger->debug( "output files " , join(",", @{$hash->{output}}),"\n");

if( defined($ENV{CELGENE_AWS})){
	$hash->{ 'instance-type' }=`curl http://169.254.169.254/latest/meta-data/instance-type`;
	$hash->{ 'ami-id' }=`curl http://169.254.169.254/latest/meta-data/ami-id`;

}


foreach my $outputfileObj( @{$hash->{output}} ){
	my ( $outputFilename, $outputDirectory,$suffix)=fileparse($outputfileObj->absFilename() );
	$logger->debug("directory: $outputDirectory, file: $outputFilename");
	my $metadataStore=MetadataPrepare->new();
	# add the derived from files that the user has explicitly provided

	# FilePath is added by the MetExtractor itself
	#$metadataStore->addMetadata("FilePath", $outputfileObj->absFilename());
	#$metadataStore->addMetadata("FilePath", $outputfileObj->userFileName()) if ($outputfileObj->userFileName() ne $outputfileObj->absFilename());
	foreach my $k(keys %$hash ){
		next if $k eq 'output';
		next if $k eq 'possiblefiles';
		
		if(ref $hash->{$k} eq 'ARRAY'){
			foreach my $v( @{$hash->{$k}} ){
				$metadataStore->addMetadata( $k,$v );
			}
		}
		else{
			$metadataStore->addMetadata( $k, $hash->{$k} );
		}
	}
	$metadataStore->storeOODT(  $outputDirectory. "/".$outputFilename . ".met");
	$logger->info("Metadata stored in file ".$outputDirectory. "/".$outputFilename . ".met");
}

$logger->debug("Finished running $originalCommand");









sub setUpLog{
	
	my ($logLevel,$logFile)=("INFO","$ENV{HOME}/celgeneExec.log");
	if(defined($ENV{ CELGENE_EXEC_LOGFILE } ) ){ $logFile = $ENV{ CELGENE_EXEC_LOGFILE } ; }
	if(defined($ENV{ CELGENE_EXEC_LOGLEVEL } ) ){ $logLevel = $ENV{ CELGENE_EXEC_LOGLEVEL } ; }
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
	
	
	my $logger=Log::Log4perl->get_logger("celgeneExec");
	return $logger;
}

sub printUsage{
	print "
============================================================================================================	
$0 version $version
a program by K.Mavrommatis (kmavrommatis\@celgene.com)

This is wrapper that can be used to execute programs from the command line and 
and keep track of associated processing metadata.
The script executes the command line provided. If you wish to include pipe symbos in the command line (e.g. |, > , >>)
	make sure that are flanked by spaces. You can submit multiple commans separated by semi colon (;) but make sure it
	is flanked by spaces. Special characters (e.g. double quote \") need to be escaped.
a. identifies files that have been used as input to the command. 
    These are files that are mentioned in the command line and they are present at the time of execution.
b. identifies files that have been created by the command.
    These are files or directories that are mentioned in the command line but were not present before.
    If a file is used from an output pipe (>) the script recognizes that, provided that the pipe symbol is 
    flanked by spaces e.g. 'blahblah > output' NOT 'blahblah> output'
c. creates a .met file with metadata which can be added to the OODT NGS database.
	The metadata will contain the time,host of execution, the user that executed it, AWS specific information if applicable,
	command line, version of script or binary that was executed etc.   
    In order for the metadata to be captured the OODT crawler needs to be run.

Optional arguments include:
	--ignorefail the script will capture errors from executed commands and continue with a warning. Otherwise it exits when a command fails
	--analysis_task --analysistask -a <integer> the analysis task for each command in the NGS database
	--loglevel  Log Level. Log level is by default set to [INFO]
		Environmental variable [\$CELGENE_EXEC_LOGLEVEL] can be used to set the Log file. 
		This option has priority over other methods
	--logfile Log File. Log file is by default set to $FindBin::RealBin/celgeneExec.log. 
		Environmental variable [\$CELGENE_EXEC_LOGFILE] can be used to set the Log file. 
		This option has priority over other methods
	--derivedfrom --derived_from -d a file with a list of input files. 
		Typically used when the command line reads the input from a list file.
	--derivedfromfiles --derived_from_files -D a comma separated list of derived from files. The script does not
		check if these file exist. This is an option suitable for adding s3 objects in the derived_from list.
	--outputfile --output --output_file -o output_file (can be used multiple times)
		Used in cases where output file is not mentioned in the command line.
	--metadatastring a string that contains the metadata key and either a value or a filename with the values. This option can be provided multiple times
	    E.g. config=rumnme.config, 
	    will add the metadata field config with value the contents of the runme.config file.
	    E.g. config='Hello world'
	    will add the metadata field config with value 'Hello world'
	--version show the version of the script and exit
	--h --help this screen
	
Examples
	celgeneExec.pl \"samtools sort /test/test.bam > /test/test.sorted.bam\"
	will execute the command [samtools sort /test/test.bam > /test/test.sorted.bam]
	     identify file /test/test.bam as input (aka derived_from)
	     identify file /test/test.sorted.bam as output 
	     will create the file /test/test.sorted.bam.met with metadata for ingestion to OODT
============================================================================================================		
	\n";
	
}
