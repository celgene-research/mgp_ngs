#!/usr/bin/perl -w
# script to update the SOLR database with fields and values of choise
use strict;
use Frontier::Client;
use Celgene::Utils::ArrayFunc;
use Data::Dumper;
use File::Find;
use File::Spec;
use FindBin;
use Log::Log4perl;
use lib $FindBin::RealBin;
use Getopt::Long;
use Cwd;
use Celgene::Utils::SVNversion;
use lib $FindBin::RealBin."/lib";
use metadataFunc;
use Sys::Hostname;

my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-06-26 12:39:03 -0700 (Fri, 26 Jun 2015) $ $Revision: 1622 $ by $Author: kmavrommatis $' );

my($help,$recursive,$showversion,$logLevel,$logFile);
GetOptions(
	"r|recursive"=>\$recursive,
	"h|help"=>\$help,
	"loglevel=s"=>\$logLevel,
	"logfile=s"=>\$logFile,
	"version!"=>\$showversion
);
if(defined($showversion)){
	print "updatedSOLR.pl $version\n";
	exit(0);
}

my $logger=setUpLog();

$logger->info("##########################");
$logger->info("update file location in OODT. By K. Mavrommatis.");
if(defined($help)){ printHelp(); exit 0 ; }


my ($oldFilename,$newFilename)=@ARGV;



if(!defined($oldFilename) or !defined($newFilename)){
	printHelp() ; 
	$logger->logdie("Please provide the oldFilename and newFilename");
	exit(1);
}



my $server = metadataFunc::getServer();


$oldFilename =sanitizeFilename( $oldFilename );
$newFilename =sanitizeFilename( $newFilename );


my @oldfnames;
my @newfnames;

my @filenameList;
my $useDirectoryId;
if(defined($recursive) and -d $oldFilename ){
	$logger->info("Traversing the old directory [$oldFilename] to update the location of the included files");
	find( \&mvFile , $oldFilename );
	@oldfnames=@filenameList;
	
}elsif( defined($recursive) and -d $newFilename){
	$logger->info("Traversing the new directory [$newFilename] to update the location of the included files");
	find( \&mvFile , $newFilename);
	@newfnames= @filenameList;
}elsif(!defined($recursive) and -d $oldFilename ){
	$logger->info("Assuming hierarchical ingestion of directory. Traversing the old directory [$oldFilename] to update the location of the included files");
	find( \&mvFile , $oldFilename );
	@oldfnames=@filenameList;
	$useDirectoryId='TRUE';
	
}elsif( !defined($recursive) and -d $newFilename){
	$logger->info("Assuming hierarchical ingestion of directory. Traversing the new directory [$newFilename] to update the location of the included files");
	find( \&mvFile , $newFilename);
	@newfnames= @filenameList;
	$useDirectoryId='TRUE';
}else{
	updateSOLR( $oldFilename, $newFilename); #for simple files
}



my $SOLRDocId;
for(my $i=0; $i< scalar(@filenameList); $i ++){
	if(!defined($oldfnames[$i])){
		($oldfnames[$i]= $newfnames[$i])=~ s!$newFilename!$oldFilename! ;
	}
	if(!defined($newfnames[$i])){
		($newfnames[$i]= $oldfnames[$i])=~ s!$oldFilename!$newFilename! ;
	}
	if($oldfnames[$i] =~ /.met$/ or $newfnames[$i] =~/.met$/
	 or $oldfnames[$i] =~ /.lock4transfer$/ or $newfnames[$i] =~/.lock4transfer$/){
	 	$logger->debug("We don't process met or lock4filetransfer files");
	 	next;
	 }
	
	my $id=updateSOLR( $oldfnames[ $i ], $newfnames[  $i ], $SOLRDocId);
	if($i==0 and $useDirectoryId eq 'TRUE'){ $SOLRDocId=$id;}
}



sub abs_path{
	my($fn,$type)=@_;
	my $absFn;

	if( $fn !~/^s3:/){
		$absFn=Cwd::abs_path( $fn) if $type eq 'cwd';
		$absFn=File::Spec->rel2abs( $fn) if $type eq 'spec';
	
	}else{
		$absFn = $fn;
	}
	$logger->debug("\nabs_path: file is $fn\n".
	                 "          became  $absFn\n".
	                 "          using   $type") if defined $absFn;
	return $absFn;
}

sub modifyPath{
	my ($old, $new, $type)=@_;
	$logger->debug("\nmodifyPath: old is $old\n".
	               "            new is $new\n".
	               "            type is $type");
	my ($absOldFilename,$absNewFilename)=
	( abs_path($old, $type), abs_path($new, $type));
	
	if(defined($absOldFilename) and !defined($absNewFilename)){
		$logger->debug("modifyPath: new name is not found it will be derived from the old name ");
		$absNewFilename= $absOldFilename;
		$absNewFilename=~s!$oldFilename!$newFilename!;
		if($absOldFilename eq $absNewFilename){$absNewFilename=undef;}
	}
	if(!defined($absOldFilename) and defined($absNewFilename)){
		$logger->debug("modifyPath: old name is not found it will be derived from the new name ");
		$absOldFilename= $absNewFilename;
		$absOldFilename=~s!$newFilename!$oldFilename!;
		if($absOldFilename eq $absNewFilename){$absOldFilename=undef;}
	}
	
	
	$logger->debug("modifyPath: returning old $absOldFilename\n") if (defined($absOldFilename));
	$logger->debug("modifyPath: returning new $absNewFilename\n") if (defined($absNewFilename));
	
	return($absOldFilename,$absNewFilename);
}
	
	
	
# uupdate SOLR does the basic work
#input $old filename
#      $new filename
#      $id  SOLR document id, If set to a value (pointer to array) the script will use always the same id 
#           this is used when need to update the locations of directories tha thave been ingested as one object
sub updateSOLR{
	my($old, $new, $id)=@_;
	
	$logger->debug("updateSOLR: $old -> $new");
	
	if( $old !~/s3:/ and -d $old){
		$logger->info("       information refers to directories");
		if(substr($old, -1 ) ne  '/'){ $old.="/";}
		if(substr($new, -1 ) ne  '/'){ $new.="/";}
	}
	elsif(  $new !~/s3:/ and -d $new){
		$logger->info("       information refers to directories");
		if(substr($old, -1 ) ne  '/'){ $old.="/";}
		if(substr($new, -1 ) ne  '/'){ $new.="/";}
	}
	
	$logger->info("Updating [$old]");
	
	my ($absOldFilename,$absNewFilename)=modifyPath($old,$new, 'cwd');
	my ($absOldFilename2,$absNewFilename2)=modifyPath($old,$new, 'spec');
	$logger->info("     absolute path of old location [$absOldFilename]") if defined($absOldFilename);
	$logger->info("     absolute path of old location [$absOldFilename2]") if defined($absOldFilename2);
	$logger->info("     absolute path of new location [$absNewFilename]") if defined($absNewFilename);
	$logger->info("     absolute path of new location [$absNewFilename2]") if defined($absNewFilename2);
	
	# get the solr id of the existing file
	my $result;
	if(!defined($id) ){
		$result=getSOLRID($absOldFilename,$absOldFilename2);
		
	}else{
		$result=$id;
		$logger->debug("Using previously assigned id [$id]");
	}
	
	
	
	if(!defined($result) or scalar(@$result)==0){
		$logger->warn( "Did not receive any id for file [$old]. This probably means that this file is not in the OODT database");
		
	}
	# add the old value as FilePath (used for older entries that don't have this setup);
	foreach my $r( @$result){
		$logger->debug( "Updating id:$r from $old to $new\n");
		serverCall("metadataInfo.updateFieldBySOLRID",
		"FilePath",
		$old,
		$r) if (defined( $absOldFilename) and $absOldFilename ne "" );
		serverCall("metadataInfo.updateFieldBySOLRID",
		"FilePath",
		$absOldFilename2,
		$r) if (defined($absOldFilename2) and $absOldFilename2 ne "");
		#add the new filepath
		serverCall("metadataInfo.updateFieldBySOLRID",
		"FilePath",
		$absNewFilename,
		$r) if(defined($absNewFilename)and $absNewFilename ne "");
		serverCall("metadataInfo.updateFieldBySOLRID",
		"FilePath",
		$absNewFilename2,
		$r) if(defined($absNewFilename2) and $absNewFilename2 ne "");

		
	}
	return $result;
}
exit(0);



sub setUpLog{
	my $hostname=hostname;
	if(defined($ENV{ UPDATESOLR_LOGFILE } ) ){ $logFile = $ENV{ UPDATESOLR_LOGFILE } ; }
	if(defined($ENV{ UPDATESOLR_LOGLEVEL } ) ){ $logLevel = $ENV{ UPDATESOLR_LOGLEVEL } ; }
	if(!defined($logLevel)){$logLevel="FATAL";}
	if(!defined($logFile)){$logFile="$ENV{HOME}/updateSOLR-${hostname}.log";}
	my $logConf=qq{
		log4perl.rootLogger          = $logLevel, Logfile, Screen
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
	my $logger=Log::Log4perl->get_logger("updateSOLR");
	return $logger;
}

sub printHelp{
	print "updateSOLR.pl $version\nis a script that updates the location of a file in the SOLR database that supports OODT\n".
		"it needs to know the url of the NGS server (by means of setting the env variable NGS_SERVER_URL)\n\n".
		"usage:\n".
		"updateSOLR.pl <options> oldFilename newFilename\n\n".
		"options :\n".
		"-h | --help this screen\n".
		"-r | -R | --recursive with update the names of all the files under the directory 'oldFilename'\n".
		"--version print the version of the script and exit\n".
		" NOTES: life is easier if this script is used BEFORE the files are moved. \n".
		"        life can be even more easy if the filenames are give as absolute paths with their soft links resolved\n".
		"        after all this is a script developed to hack the need for updating metadata, and not a production level, robust software ;)";
}
sub sanitizeFilename{
	my($fn)=@_;
	
	if(!defined($fn)){return undef;}
	$fn=~s!//!/!g;  # remove double slashes
	if(substr($fn, -1 )eq '/'){ chop $fn;} #remove slash from the end
	$fn =~s!^s3:/!s3://!; # for s3 objects we need double slashes
	return $fn;
}

sub getSOLRID{
		my( $absOldFilename, $absOldFilename2)=@_;
		my $result=[]; $result=serverCall("metadataInfo.getSOLRIDByFilename",
		$absOldFilename )if defined($absOldFilename);
		my $result2=[]; $result2=serverCall("metadataInfo.getSOLRIDByFilename",
		$absOldFilename2 ) if defined($absOldFilename2);
		@$result=(@$result,@$result2);
		$result=Celgene::Utils::ArrayFunc::unique($result);
		#print Dumper($result);
		return $result;
		
	}


sub mvFile{

	my $oldLocation = $File::Find::name  ;
	push @filenameList, $oldLocation;
	$logger->debug("mvFile: found file $oldLocation");
}