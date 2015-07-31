package iRODS_OO_Func;

use strict;
use warnings;
use CommonFunc;
use File::Spec;


sub new{
	my ($class,$password)=@_;
	my $self={};
	bless $self, $class;
	$self->{logger}=Log::Log4perl->get_logger("iRODS_OO");
	$self->initialize($password);
	return $self;
}

# initialize irods by running iinit
sub initialize{
	my ($self, $password)=@_;;

	$self->{logger}->debug("initialize: with password $password");	
	my $cmd="iinit $password";
	CommonFunc::runCmd( $cmd );
	
	my $cmd2="ienv";
	my @l=`$cmd2`;
	foreach my $l(@l){
		chomp $l;
		$self->{logger}->trace("initialize: got $l");
		if($l=~/Release Version = (\S+)/){ $self->{releaseVersion}=$1;}
		if($l=~/irodsHost=(\S+)/){ $self->{irodsHost}=$1;}
		if($l=~/irodsHome=(\S+)/){ $self->{irodsHome}=$1;}
	}
}

# find the collection of a file given its name on the file system
# or in the irods filesystem
# it does this by comparing the filename and a number of directories
# to the collection name, 
sub getFileCollection{
	my($self, $fullFilePath)=@_;
	$self->{logger}->trace("getFileCollection: finding collection for file $fullFilePath");
	# make sure the fullFilePath is an absolute path
	$fullFilePath=File::Spec->rel2abs( $fullFilePath);

	$self->{logger}->debug("Will look for the collection that holds the file [$fullFilePath]");
	if(defined( $self->{fileCollection}->{$fullFilePath}->{collection} ) ){
		my $collection = $self->{fileCollection}->{$fullFilePath}->{collection};
		my $dataName=$self->{fileCollection}->{$fullFilePath}->{dataName};
		return wantarray ? ($collection, $dataName) : $collection;
		
	}
	
	# find the collections for all the files with this name in the database
	my $cmd;
	if( -f $fullFilePath){
		$cmd= qq{ iquest "SELECT COLL_NAME, DATA_NAME where DATA_PATH = '$fullFilePath'"};
	} # this will work when we ask for the collection of a file
	else{
		$cmd= qq{ iquest "SELECT COLL_NAME where DATA_PATH like '$fullFilePath%'"};
	} # this will work if we ask for the collection of a directory 
	# parse the results
	$self->{logger}->debug("getFileCollection: querying iRODs\n\t$cmd");
	my @res=`$cmd`;

	my $collection;
	my $dataName="";
	foreach my $l(@res){
		chomp $l;
		if($l=~/\/trash\//){next;} # we don't want to present the results that are in trash
		$self->{logger}->trace("getFileCollection: parsing line $l");
		if($l=~/^ERROR/){
			return undef;
		}
		if($l=~/^COLL_NAME = (.+)/){
			$collection=$1;
		}
		if($l=~/^DATA_NAME = (.+)/){
			$dataName=$1;
		}
	}
		

	$self->{fileCollection}->{$fullFilePath}->{collection}=$collection;
	$self->{fileCollection}->{$fullFilePath}->{dataName}=$dataName;
	#check if we got more than one collection
	$self->{logger}->debug("getFileCollection: Found collection [$collection]\n\tand data name [$dataName") if defined($collection);
	return wantarray ? ($collection, $dataName) : $collection;
}





# get teh irods home directory
sub getHomeDir{
	my($self)=@_;
	return($self->{irodsHome});

}


# add metadata to a file 
# requires the full filename in the filesystem
# and a attribute,value,unit triplet
sub putMetadata{
	my($self, $fsFullFile, $attribute,$value,$unit)=@_;
	my $typeFlag=" -d ";
	if( -d $fsFullFile){$typeFlag=" -C ";}
	my ($collection,$filename)=$self->getFileCollection($fsFullFile);
	my $cmd="imeta add $typeFlag $collection/$filename $attribute '$value'";
	if(defined($unit)){$cmd.=" '$unit'";}
	my @res=`$cmd 2>&1`;
	foreach my $l(@res){
		$self->{logger}->trace("putMetadata: parsing line $l");
		if($l=~/CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME/){
			$self->{logger}->debug("putMetadata: file [$collection/$filename] already contains [$attribute/$value] metadata");
			return;
		}
		if($l=~/ERROR/){
			$self->{logger}->logdie("putMetadata: \n\tCommand $cmd failed \n\t$l");
		}
	}	
	$self->{logger}->debug("Command $cmd executed successfully");
}



# get the AVUs of a file
# it assumes that the provided filename is the full filename in the filesystem.
# if the filename is in the irods then the third argument should be 'irods'

sub getMetadata{
	my ($self, $fn, $attr)=@_;
	my ($collection,$filename)=$self->getFileCollection($fn);
	if(!defined($collection)){
		$self->{logger}->debug("getMetadata: the file $fn is not in the IRODs collection");
		return undef;
	}
#	my($file,$directory,$suffix)=fileparse($fn);
	$self->{logger}->debug("getMetadata: find [$attr] for file [$collection/$filename]");
	if(!defined($self->{AVUhash}->{processed}->{$fn})){
		$self->{AVUhash}->{$fn}={};
		$self->{AVUhash}->{processed}->{$fn}=1;
		my $typeFlag=" -d ";
		if(-d $fn){ $typeFlag = " -C ";}
		my $cmd="imeta ls $typeFlag $collection/$filename";
		my @a=();
		my $attribute="";
		$self->{logger}->debug("getMetadata: Retrieving meta data $cmd");
		foreach my $a( `$cmd`){
			$self->{logger}->debug("Retrieved $a");
			if($a=~/does not exist.$/){ return undef;} # this file does not exist in iRODs
			
			if($a=~/^attribute: (.+)/){
				$attribute =$1;
			}
			if( $a=~/^value: (.+)/){
				my $value =$1;
				if(!defined($self->{AVUhash}->{$fn}->{$attribute})){
					$self->{AVUhash}->{$fn}->{$attribute}=[];
				}
				push @{$self->{AVUhash}->{$fn}->{$attribute}}, $value;
			}
		}
	}else{
		$self->{logger}->debug("getMetadata: seems that this file has been queried before");
	}
	
	if(defined( $self->{AVUhash}->{$fn}->{$attr})){
		$self->{logger}->debug("getMetadata: found value :", join(",",@{$self->{AVUhash}->{$fn}->{$attr}}) );
		return @{$self->{AVUhash}->{$fn}->{$attr}};
	}
	
	$self->{logger}->debug("getMetadata: could not find metadata for [$attr] for file [$fn]");
	return undef;
}


1;
