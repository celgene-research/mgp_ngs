package FileConversion;
use Celgene::Utils::FileFunc;
use strict;
use warnings;
my $logger=Log::Log4perl->get_logger("fileConversion");
# use the function in this package to run a 'on the fly' converson of the 
# filenames between the S3 and local directories

my %cfHash;
# the conversion rules are expected to be in either a .cf-config file in the home directory,
# or a cf-config file in the current directory
# or a file pointed by tthe environment variable CF_CONFIG
# local directory is prefered over the user directory
sub _findConfigFilename{
	my $configFilename;
	if( defined($ENV{ CF_CONFIG } ) and -e $ENV{ CF_CONFIG } ){
		$configFilename=$ENV{ CF_CONFIG };
		return $configFilename;
	}
	
	if( -e "cf-config"){
		$configFilename="cf-config";
		return $configFilename;
	}
	
	if( -e "$ENV{HOME}/.cf-config"){
		$configFilename="$ENV{HOME}/.cf-config";
		return $configFilename;
	}
	
	$logger->logdie( "There is no cf-config, or $ENV{HOME}/.cf-config or any file pointed by the \$CF_CONFIG variable");
	return undef;
}

sub _loadConfig{
	
	if( scalar( keys(%cfHash) )  >0 ){return;}
	my $configFilename=_findConfigFilename();
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle( $configFilename );
	$logger->debug("Contents of $configFilename");
	while(my $line=<$rfh>){
		chomp $line;
		my($platform, $dir)=split("=", $line);
		my @dirs=split(",",$dir);
		$cfHash{ $platform }=\@dirs;
		$logger->debug("Platform $platform\t",join("  ", @dirs));
	}
	
}


sub _convertfn{
	my($filename,$from,$to)=@_;
	_loadConfig();
#	conversionpath=data.frame(
#		windows=c("C:/Users/kmavrommatis/","C:/Users/kmavrommatis/","S:/celgene-ngs-data/"),
#		linux=c("/gpfs/home/kmavrommatis/","/home/kmavrommatis/","/home/kmavrommatis/S3/"),
#		aws=c(NA,NA,"s3://celgene-ngs-data/")
#	)
	$from=lc($from);
	$to=lc($to);
	$logger->debug( "convertFn: filename is [$filename]");
	$logger->debug( "convertFn: origin is [$from]");
	$logger->debug( "convertFn: destination is [$to]");
	
	
	my @fromArray= @{$cfHash{ $from }};
	my @toArray=@{$cfHash{ $to }};
	
	
	for(my $i=0; $i< scalar(@fromArray); $i ++){
		if( !defined( $toArray[$i]) or $toArray[$i] eq "" or
		    !defined( $fromArray[$i]) or  $fromArray[$i] eq "" ){
		    	next;
		    }
		$logger->debug("Checking if filename contains $fromArray[$i]");
		if( $filename =~/^$fromArray[$i]/){
			$logger->debug("It does, will be replaced by $toArray[$i]");
			$filename =~s/^$fromArray[$i]/$toArray[$i]/;
			last;
		}
		
	}
	return $filename;
}


sub _dispatch{
	my($filename,$direction,$system)=@_;
	$logger->debug("_dispatch: direction is $direction ");
	if($direction eq "windows"){
		$filename=_convertfn($filename,"linux","windows");
		$filename=_convertfn($filename,"aws","windows");
	}
	elsif($direction eq "linux"){
		$filename=_convertfn($filename,"windows","linux");
		$filename=_convertfn($filename,"aws","linux");
	}
	elsif($direction eq "toaws"){
		$filename=_convertfn($filename,$system,"aws");
	}
	else{
		$logger->logdie( "Unknown direction ",$direction," for file conversion" );
	}	
	return $filename;	
}

sub cf{
	my($filename,$direction)=@_;
# lets find out what environment we are in		
	my $system= $^O;
	$logger->debug("Detected OS $system");
	if(!defined($direction)){$direction=lc($system)}
	$direction=lc($direction);
	$logger->debug("Direction for conversion is $direction");
	$filename=_dispatch($filename, $direction,$system);
	$logger->debug("Final filename is $filename");
	return($filename);

}
1;