#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use File::Path qw(mkpath rmtree);
use File::Basename;
use File::Find;
use Cwd;
use Log::Log4perl;
use FindBin;
use lib $FindBin::RealBin;
use lib $FindBin::RealBin."/lib";
use configParser;
use Getopt::Long;
use Cwd;
use Celgene::Utils::SVNversion;


my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-10-12 17:09:33 -0700 (Mon, 12 Oct 2015) $ $Revision: 1696 $ by $Author: kmavrommatis $' );

my($help,$type,$operation,$flag,$forcecopy,$forcelink,$logLevelArg,$logFileArg,$showversion);
GetOptions(
	"t|type=s"=>\$type,
	"o|operation=s"=>\$operation,
	"forcelink!"=>\$forcelink,
	"forcecopy!"=>\$forcecopy,
	"n|name!"=>\$flag,
	"h|help!"=>\$help,
	"loglevel=s"=>\$logLevelArg,
	"logfile=s"=>\$logFileArg,
	"version!"=>\$showversion
);
if(defined($showversion)){
	print "stage.pl $version\n";
	exit(0);
}

if(defined($help)){printUsage(); exit 0;}


	
	
sub printUsage{
	print "stage.pl $version
File staging utility by K.Mavrommatis (kmavrommatis\@celgene.com)
	
use:
	$0 <options> filename
options are:
	-t | --type type of object to stage ([file] | directory)
	-o | --operation type of operation (in | [out]) (out means stage files in a local tmp space, in means return to safe location)
	--forcelink force to use soft links and not copy files (does not work if files are in AWS)
	--forcecopy force to copy files to local temporary location (specified by NGS_TMP_DIR)
	-n | --name Will return the name of the object in the new location but not copy. Useful for debugging or dry runs.
	-h | --help This screen 
	--loglevel,--logfile standard log options
	--version  print the version of the script and exit
	
	\n"
}
	my ($logLevel,$logFile)=("INFO","$ENV{HOME}/stage.log");
	if(defined($logFileArg)){ $logFile = $logFileArg}
	elsif(defined($ENV{ STAGEFILE_LOGFILE } ) ){ $logFile = $ENV{ STAGEFILE_LOGFILE } ; }
	
	if(defined($logLevelArg)){ $logLevel=$logLevelArg;}
	elsif(defined($ENV{ STAGEFILE_LOGLEVEL } ) ){ $logLevel = $ENV{ STAGEFILE_LOGLEVEL } ; }
my $logger=setUpLog();




$logger->info("##########################");
$logger->info("File staging utility by K.Mavrommatis");

my $configuration=configParser->new();

sub getFullFilePath{
	my($file)=@_;
	
	
	$file=File::Spec->rel2abs( $file);
	$file=Cwd::abs_path( $file ); # this will resolve symlinks which is not desirable
	return ($file);
	
}
# script to stage files and directories in a temporary directory
# USAGE:
# stage.pl 
#			<filename> 
#			<[file]/directory>     : the type of the object to stage
#			<operation [out]/in>   : out=get from S3, in=put in S3
#			<[datatransfer]/name>  : datatransfer=full transfer, name=get only the name 

my ($object)=@ARGV;
if(!defined($object)){$logger->logdie("Please provide the object name to stage\n");}
#object=$1   # the filename or directory to stage
#type=$2     # type of object [file]/directory
#operation=$3 # type of operation [out] to get from S3/in to put in S3
#flag=$4    # decide what to do with the object [datatransfer] to try data transfer /name to return the name of the object only 
if (!defined($type)){
	$type='file';
}
if (!defined($operation)) {$operation='out'}
if (!defined($flag)){$flag='datatransfer'}else{$flag='name';}




##############################################################
# debug setting. The script will check for env variable NGS_TMP_DIR_DEBUG 
#if [ -n "$NGS_TMP_DIR_DEBUG" ]; then
#	NGS_TMP_DIR=${NGS_TMP_DIR_DEBUG}
#	flag='name'
#	echo "-------- Entering DEBUG MODE ----------------------------" 1>&2
#fi 
##############################################################
my $useLinks=undef;

if(defined($ENV{STAGE_WITH_LINK}) or defined($forcelink)){
	$logger->info("Staging will use soft links ");
	$useLinks=1; # set this variable if instead of copying files we want to link to them (in the out operations for local environment)
	
	if($object =~/^s3/){
		$logger->warn("Cannot use softlinks when the input object is an s3 object");
		$useLinks=undef;
	}
	
}
if(!defined($ENV{STAGE_WITH_LINK}) or defined($forcecopy)){
	$logger->info("Staging will copy files on the target location (no soft links option set)");
}
if(!defined($ENV{NGS_TMP_DIR})){
	$logger->logdie( "Cannot find the temporary directory. Env variable NGS_TMP_DIR is not set\n");
}
my $NGS_TMP_DIR=sanitizeFilename(  $ENV{NGS_TMP_DIR}  );
$NGS_TMP_DIR=getFullFilePath($NGS_TMP_DIR);

if(!defined($NGS_TMP_DIR)){
	$logger->logdie( "Cannot find the temporary directory. Env variable NGS_TMP_DIR is not set\n");
}



my $CELGENE_NGS_BUCKET=sanitizeFilename( $ENV{CELGENE_NGS_BUCKET} );
if(!defined($CELGENE_NGS_BUCKET)){ $CELGENE_NGS_BUCKET="";}
if( substr( $CELGENE_NGS_BUCKET , -1) eq '/' ){ chop $CELGENE_NGS_BUCKET; }
my $aws; if(defined($ENV{CELGENE_AWS})){ $aws =1; }




my ($src, $dest);


###############################################################
# begin staging
$logger->info("NGS temporary directory is set to [$NGS_TMP_DIR]");
if (defined($aws)){
	$logger->info("We are in AWS: Celgene Bucket is set to [$CELGENE_NGS_BUCKET]");
}
$object=getObjectPath($object);


$logger->info("Staging object [$object]");
$logger->info("    type:[$type], operation:[$operation], mode:[$flag]");
($src,$dest)=setSourceDest($object);
$logger->info("    Source     :[ $src ]");
$logger->info("    Destination:[ $dest ]");



# if the only thing needed is the filenaem we print it and exit;
if ($flag eq 'name'){
	$logger->info("Only staged name requested.");
	$logger->info("The staged name will be\n  [$dest]");
    print $dest;
    exit(0);
}


fileTransfer();



$logger->info("Updating FilePath 1of file $src to $dest in OODT");
if($type eq 'file'){
	runCmd("updateSOLR.pl --logfile $logFile --loglevel $logLevel $src $dest &>/dev/null");
}
if($type eq 'directory'){
runCmd("updateSOLR.pl --logfile $logFile --loglevel $logLevel --recursive $src $dest &>/dev/null");
}

$dest=~s!//!/!g;
$dest=~s!^s3:/!s3://!;
print $dest;

# get the absolute full path of the file (or keep the same if it is an S3 object)

sub getObjectPath{
	my($object)=@_;
	$logger->debug("getObjectPath: received $object");
	my $isS3='no';
	if($object =~/(^s3:\/\/[a-z,A-Z,\-,\.]+)/  ){

                $isS3='yes';
                my $object_bucket=$1;
                if($object_bucket ne $CELGENE_NGS_BUCKET){
                        $logger->warn("getObjectPath: the s3 bucket of this object [$object_bucket] is different than the default bucket [$CELGENE_NGS_BUCKET]. I will proceed with the new information.");
                        $CELGENE_NGS_BUCKET=$object_bucket;
                }
	}else{
		$object=
		getFullFilePath( $object );
	}
	$logger->debug("getObjectPath: full path is $object");
	if( defined($CELGENE_NGS_BUCKET) and $CELGENE_NGS_BUCKET ne ""){
		$object=~s!$CELGENE_NGS_BUCKET!!;
		$logger->debug("getObjectPath: after removing bucket string $object");
	}
	#print "\nremoving $NGS_TMP_DIR from $object\n";
	$object=~s!$NGS_TMP_DIR!!;
	$logger->debug("getObjectPath: after removing NGS_TMP_DIR $object");
	#print "now became $object\n\n";
	return $object;
}

# set the destination and source filepaths, and create destination if necessary
sub setSourceDest{
	my ($object)=@_;
	my ($src,$dest);
	
	
	
	#$logger->info("Initiating data transfer process on local storage");
	if ($operation eq 'out'){
		$src="${CELGENE_NGS_BUCKET}/${object}" ;
		$dest="${NGS_TMP_DIR}/${object}" ;
		
	}
	
	if  ($operation eq 'in'){
		$dest="${CELGENE_NGS_BUCKET}/${object}";
		my($name,$path,$suffix)=fileparse( $dest);
		my $res=mkpath( $path );
		$src="${NGS_TMP_DIR}/${object}";
		
	}    
	
	$dest=sanitizeFilename($dest);
	$src =sanitizeFilename($src);
	
#	if(defined($useLinks)){
#		$dest= $src;
#	}
	return($src,$dest);
}


# synchronize files on local filesystems
sub syncFilesLocal{
	my($source,$destination)=@_;
	my $CMD;
	
	 my($name,$path,$suffix)=fileparse( $destination);
	 my $res=mkpath( $path );
	
#	# check if the transfer has already started (by another thread ?) and wait until it is done
#	# otherwise lock the file transfer
#	open(my $wfh,">>$destination.lock4filetransfer") or $logger->logdie( "Cannot lock file $destination\n");
#	flock ($wfh,2); # Apply an exclusive lock
#	print $wfh "copying file from $source. Pid = $$\n";
		
	if($type eq 'file'){
		$CMD="rsync -aq $source $destination ";
	}else{
		$CMD="rsync -aq --recursive $source/ $destination";
	}
	if( $operation eq 'out' and defined($useLinks) ){ 
		$CMD="ln -sf  $source $destination";
		
		# Keeping as $dest the same as $src results in problems because the output file path
		# is not correctly set
		#$CMD="echo 'Not copying file since links are used in the staging phase'&>2";
	}
	my $ret=runCmd($CMD);
	if($ret != 0){
		print 'FAILED';
		$logger->logdie( "*** ERROR *** Data transfer of file $source to $destination failed\n"); 
	}
#	close($wfh);
}
sub syncFilesCloud{
	my($source,$destination)=@_;
	$logger->info("Initiating data transfer process between AWS and local storage");
	my $CMD;
	my $ret=0;
	    if( $source =~/^s3:/){
	    	$logger->info("Initial file location detected on the cloud");
#	    	my $lockfile=$destination.".lock4filetransfer";
	    	my($name,$path,$suffix)=fileparse( $destination);
	    	my $res=mkpath( $path );
#	    	open(my $wfh,">>$lockfile") or die "Cannot lock file $destination\n";
#	    	flock ($wfh,2); # Apply an exclusive lock
#            print $wfh "copying file from $source. Pid = $$\n";
            
            if( $type eq 'file' ){
                if( -e $destination){
                        $logger->warn(" destination [$destination] for file transfer already exists\n");
#                        print $wfh "\t\tFile has already been copied by a different process\n"
                }else{
                        #$CMD="s3-mp-download.py -f -np 4 -f -t 3 $source $destination 1>&2 " if $type eq 'file'; # use this to take advandage of parallel transers
                        $CMD=$configuration->{copy_file_from_aws}." $source $destination 1>&2" if $type eq 'file'; # use s3cmd because s3-mp-download gives error ERROR:s3-mp-download:do_part_download() takes exactly 1 argument (9 given) which I have not managed to figure out
                        
                        $ret=runCmd($CMD);
                }
                
             }else{
             	if( -d $destination){
             		$logger->warn(" destination [$destination] for full directory transfer already exists\n");
#                    print $wfh "\t\tFile has already been copied by a different process\n";
             	}else{
					my $res=mkpath( $destination );
	                $CMD=$configuration->{copy_dir_from_aws}" $source/ $destination/  1>&2" ;
	                $ret=runCmd($CMD);
             	}
             }
#             close($wfh);
        }
        if($dest=~/^s3:/){
        	$logger->info("Final file location detected on the cloud");
                $CMD=$configuration->{copy_file_to_aws}" $src $dest  1>&2"  if $type eq 'file';
                $CMD=$configuration->{copy_dir_to_aws}" $source/ $destination/  1>&2" if $type eq 'directory';
                $ret=runCmd($CMD);
                #unlink( $src ) if $type eq 'file';
                #rmtree( $src ) if $type eq 'directory';
        }
	if($ret != 0){
		print 'FAILED';
		die "Data transfer of file $source to $destination failed\n"; 
	}
}

sub runCmd{
	my ($cmd,$retries)=@_;
	if(!defined($retries)){$retries =3;}
	$logger->info("Executing command $cmd");
	my $returnCode;
	system($cmd);
	
	if ($? == -1) {
	   $logger->warn( "failed to execute: $!\n" );
	   $returnCode=-1;
	}
	elsif ($? & 127) {
	    $logger->warn( sprintf( "child died with signal %d, %s coredump\n",
	    ($? & 127),  ($? & 128) ? 'with' : 'without' ));
	    $returnCode=$?;
	}
	else {
		$returnCode=$?>>8;
		
	    $logger->warn( (sprintf( "child process exited with value %d\n", $returnCode)));
	}
	if($retries>0 and $returnCode !=0 ){ 
		$retries --;
		$logger->warn("Since command [$cmd] failed we will try once again ($retries retries left)");
		$returnCode=runCmd( $cmd, $retries)
	}
	return($returnCode);
}


sub fileTransfer{
		if(defined($aws)){
			syncFilesCloud($src, $dest);
		}else{
			syncFilesLocal($src, $dest);
		}

}

# need to sanitize source and destination
# i.e. make sure that there are no double slashes etc 
# since S3 is very sensitive to that.
# Also make sure that directories don't end with slash
sub sanitizeFilename{
	my($fn)=@_;
	
	if(!defined($fn)){return undef;}
	$fn=~s!//!/!g;  # remove double slashes
	if(substr($fn, -1 )eq '/'){ chop $fn;} #remove slash from the end
	$fn =~s!^s3:/!s3://!; # for s3 objects we need double slashes
	
	return $fn;
}



sub setUpLog{

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
	my $logger=Log::Log4perl->get_logger("stagefile");
	return $logger;
}
