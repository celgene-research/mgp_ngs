package iRODsFunc;
use strict;
use warnings;
use Log::Log4perl;
use File::Basename;
use File::Spec;
use Log::Log4perl;
my $logger=Log::Log4perl->get_logger("irodFunc");

sub initializeiRODs{
	my($password)=@_;
	
	my $cmd="iinit $password";
	system($cmd);
	if ($?) {$logger->logdie( "command: $cmd failed")};
}

# get the AVUs of a file
# it assumes that the provided filename is in the filesystem.
# if the filename is in the irods then the third argument should be 'irods'
{

my $hash={};
sub getAVU{
	my ($fn, $attr, $location)=@_;
	if(!defined($location)){$location="fs";}
	
#	my($file,$directory,$suffix)=fileparse($fn);
	$logger->debug("getAVU: find [$attr] for file [$fn]");
	if(!defined($hash->{$fn})){
		$hash->{$fn}={};
		# get the file of interest
		# it will use getiRODsFile to retrieve the location of the file. If an array is returned only the first element will be used
		my $file=$fn;
		if($location eq 'fs'){$file= getiRODsFileByFileName( $fn );}
		if(!defined($file)){$logger->warn("Cannot find $fn in the iRODs database")}
		else{
		my $cmd="imeta ls -d $file";
		my @a=();
		my $attribute="";
		$logger->debug("Retrieving meta data $cmd");
		foreach my $a( `$cmd`){
			$logger->debug("Retrieved $a");
			if($a=~/^attribute: (.+)/){
				$attribute =$1;
			}
			if( $a=~/^value: (.+)/){
				my $value =$1;
				if(!defined($hash->{$fn}->{$attribute})){
					$hash->{$fn}->{$attribute}=[];
				}
				push @{$hash->{$fn}->{$attribute}}, $value;
			}
		}
		}
		
	}
	
	
	if(defined( $hash->{$fn}->{$attr})){
		$logger->debug("getAVU: found value :", join(",",@{$hash->{$fn}->{$attr}}) );
		return @{$hash->{$fn}->{$attr}};
	}
	
	$logger->debug("getAVU: could nof find metadata for $attr for file $fn");
	return undef;
}
}

sub getiRODsHome{
	my $cmd="ienv";
	$logger->debug("getiRODsHome: get the home directory of the iRODs vault");
	while (my $l=`$cmd`){
		if ($l=~/irodsHome=(.+)/){
			$logger->debug("getiRODsHome: found $1");
			return $1;
		}
	}
	$logger->logdie("getiRODsHome: could not get the irods home directory");
	return undef;
}

# get teh irods filename in the irods database
sub parseiRODsFile{
	my ($file)=@_;
	# ilocate can use only the filename,  we strip off any path information from the file
	my ($f,$d,$s)=fileparse( $file );
	my $cmd = "ilocate '$f'";
	$logger->debug("Executing $cmd");
	my $l=`$cmd`;
	chomp $l;
	$logger->debug("File $f ($file) is in [$l]");
	if(!defined($l) or $l eq ""){ return undef; }
	
	my($filename,$directory,$suffix)=fileparse( $l );
	return ( $filename,$directory,$suffix);
}


# get teh irods filename in the irods database
# returns an array with all the possible locations that this file can be found
# alternatively if $str is defined it returns the first file that matches the given string
sub getiRODsFile{
	my ($file)=@_;
	$logger->debug("getiRODsFile: get the iRODs filename for $file");
	# ilocate can use only the filename,  we strip off any path information from the file
	my ($f,$d,$s)=fileparse( $file );
	
	my $cmd = "ilocate '$f'";
	$logger->debug("Executing $cmd");
	my @files;
	my $ret=`$cmd`;
	my @l=split(/\r?\n/, $ret);
	foreach my $l(@l){
		chomp $l;
		if($l =~/ERROR: Couldn't locate/){next;}
		push @files, $l;
		$logger->debug("File $f ($file) is in [$l]");
	}
	if(scalar(@files)==0){ 
		$logger->debug("getiRODsFile: could not find an iRODs file entry for $file");
		return undef; 
	}
	
	$logger->debug("getiRODsFile: found ", join("   ", @files));
	return @files;
}

# provide the filename on teh filesystem of an irods node
sub getiRODsFileOnFilesystem{
	my($file)=@_;
	$logger->debug("getiRODsFileOnFilesystem: find the filesystemname for file $file");
	# ilocate can use only the filename,  we strip off any path information from the file
	my ($f,$d,$s)=fileparse( $file );
	my $cmd="ils -L `ilocate '$f'` | tail -1";
	$logger->debug("Executing $cmd");
	my $l=`$cmd`;
	chomp $l;
	if(!defined($l) or $l eq ""){
		$logger->debug("getiRODsFileOnFilesystem: could not find $file in the iRODs db"); 
		return undef; 
	}
	$l=~/\s+generic\s+(.+)$/;
	$logger->debug("getiRODsFileOnFilesystem: found $1");
	return $1;
}

# get the irods file based on the filename on the filesystem
# provide the file name in the filesytem
# and returns the irods filename
sub getiRODsFileByFileName{
	my($file)=@_;
	$logger->debug("getiRODsFileByFileName: find the irods filename for file $file");
	$file=File::Spec->rel2abs( $file) ;
	# get all the irods files that have the same name (not path)
	my @f=getiRODsFile( $file );
	
	# check that the full path of this irods file is the one requested
	foreach my $f(@f){
		my $fileOnFS=_irods_ils( $f );
		if(!defined($fileOnFS)){
			$logger->warn("getiRODsFileByFileName: File $file does not exist in iRODS, skipping");
			return undef;
		}
		$logger->debug("getiRODsFileByFileName: comparing [$file] to [$fileOnFS]");
		if($file eq $fileOnFS){
			$logger->debug("getiRODsFileByFileName: found $f");
			return $f;
		}
	}
	$logger->debug("getiRODsFileByFileName: could not find the irods filename for file $file");
	return undef;
}


sub _irods_ils{
	my ($irodsFn)=@_;
	if(!defined($irodsFn) or $irodsFn eq ""){return undef;}
	my $cmd="ils -L '$irodsFn'";
	my $fsFn=undef;
	my $l=`$cmd`;
	if($l=~/\s+generic\s+(.+)$/){
		$fsFn=$1;
		$fsFn=~s/\/\.//g;
	}
	
	return $fsFn;
}

1;
