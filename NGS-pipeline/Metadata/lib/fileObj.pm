package fileObj;
use strict;
use warnings;
use Log::Log4perl;
use File::Spec;
use URI;
use File::Path qw(make_path);
use FindBin qw($RealBin);;
use Celgene::Utils::CommonFunc;
# this class supports the generic object file.
# the user submits one and the class finds the relative/absolute etc filepaths
# if the file is a URI pointing to S3 the class can get the file to the local filesystem and
# return all teh subsequent file paths relative to the local file
# call like:
# $fobj=fileObj->new( $filename,$type, $shadow );
# filename is the uri of the file name (if no scheme is provided 'file:' is assumed)
# type can be either 'regular' or 'binary' indicating if this is a data file or an executable
# shadow can be either undef or anything else. if set an S3 file will not be copied but a small "shadow" file will be created
sub new
{
    my $class = shift;
    my $filename=shift;
    my $type=shift; # can be either regular file [regular](default) or indicate that this is an executable [binary] or 'asis' to indicate no change at all
    my $shadow=shift;
	if(!defined($type)){ $type= "regular";}   
	my $self = {};
    bless $self, $class;
	
	
    
    if(!defined($shadow)){
		$self->{shadowFile}='off';
	}else{
		$self->{shadowFile}='on';
	}
    $self->{logger}=Log::Log4perl->get_logger("fileObj");
    $self->{logger}->trace("---------- fileObj -----------");
    $self->{logger}->trace("initializing object [$filename] of type [$type]");
    
    if(defined($filename)){ 
    	$self->userFileName($filename);
    	$self->filename($filename);
    	#$self->_setURI();
    }
    $self->type( $type );
    
    $self->{logger}->trace("Initialization complete");
    $self->{logger}->trace("------------------------------");
    return $self;
}

sub DESTROY{
	my($self)=@_;
	if(defined($self->{uri}) and defined( $self->{uri}->scheme() ) ){
	if($self->{uri}->scheme() eq 's3' and
	   $self->{downloadedFromS3}eq 'false'){
	   	$self->{logger}->trace("DESTROY: This is an S3 object that needs to be placed in the S3 bucket");
		# this file was not found in s3 previously indicating that this is
		# an output file.
		if(-e $self->filename()){
			my $cmd="$RealBin/s3-multipart/s3-mp-upload.py -f -np 4 -s 10 ".$self->filename(). " ". $self->{uri}->as_string() ;
			$self->{logger}->trace("DESTROY: Executing $cmd");
			my $returnCode=Celgene::Utils::CommonFunc::runCmd($cmd);
			$self->{logger}->trace("DESTROY: Return code is $returnCode");
		}
	}
	}
}

# type of file, can be "regular" or "binary"
sub type{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->trace("type: Setting the file type");
		$self->{fileType}=$value;
		if($self->{fileType} eq 'regular'){
			$self->_getFullFile( );
		}
		if($self->{fileType} eq 'binary'){
			$self->_getFullBinary( );
		}
		if($self->type() eq 'asis'){
			$self->absFilename( $self->filename());
			$self->onlyFilename( $self->filename());
			return $self->{fileType};
		}	
		my($volume,$directories,$file) = File::Spec->splitpath( $self->{fileName} );
		$self->onlyFilename( $file );
		$self->{logger}->trace("type: Finished setting the file type to $self->{fileType}");
	}
	return $self->{fileType};
}
# name of the file as provided by the user
sub filename{
	my($self,$value)=@_;
	
	if(defined($value)){
		$self->{logger}->trace("filename: Setting the filename to [$value]");
		
		$self->{fileName}=$value;
		
		
		
	}
	return $self->{fileName};
}

sub userFileName{
	my($self,$value)=@_;
	return $self->userFilename( $value );
}
sub userFilename{
	my($self,$value)=@_;
	
	if(defined($value)){
		$self->{logger}->trace("userFilename: Setting the user path to the filename [$value]");
		$self->{userFileName}=$value;
	}
	return $self->{userFileName};
}

sub absFileName{ 
	my($self,$value)=@_;
	return $self->absFilename( $value );
}
sub absFilename{
	my($self,$value)=@_;
	
	if(defined($value)){
		$self->{logger}->trace("absFilename: Setting the absolute path to the filename [$value]");
		$self->{absFileName}=$value;
	}
	return $self->{absFileName};
}

sub onlyFileName{
	my($self,$value)=@_;
	return $self->onlyFilename($value);
}
sub onlyFilename{
	my($self,$value)=@_;
	
	if(defined($value)){
		$self->{logger}->trace("onlyFilename: Setting the filename-only portion [$value]");
		$self->{onlyFileName}=$value;
	}
	return $self->{onlyFileName};
}



# get teh full path for a binary by running which if it is not already specified
sub _getFullBinary{
	my($self)=@_;
	
	my $binary=$self->filename();
	if($self->type() eq 'asis'){
		$self->absFilename( $self->filename());
		return;
	}
	my ($volume,$directories,$file) = File::Spec->splitpath( $binary );
	
	# if we have provided the full path to the binary do nothing
	if( File::Spec->file_name_is_absolute( $binary ) ){
		$self->{logger}->trace( "_getFullBinary: the provided binary $binary is already  an absolute path");
	}
	# if we have provided a relative path to the binary, which includes directory name (e.g. ./runme OR ./bin/runme )
	# convert the relative path to absolute
	elsif( defined($directories) and $directories ne ""){
		$binary=File::Spec->rel2abs( $binary );
		$self->{logger}->trace("getFullBinary: the provided binary was changed to $binary");
	}else	{

		my $cmd="bash -c \"type -t $binary\" ";
		
		my $res=`$cmd`;
		chomp $res;
		$self->{logger}->trace("command $cmd returned [$res]");
		if(!defined($res) or $res eq "" ){ 
			$self->{logger}->logdie("Cannot find binary $binary in the PATH or among the shell builtins.");
		}elsif( $res eq 'file') { 
			my $cmd2="bash -c  \"type -p $binary\" ";
			my $tmp=`$cmd2`;
			$binary  = $tmp; chomp $binary;
			$self->{logger}->trace("getFullBinary: the provided binary was converted to full path $binary")
		}else{
			$self->{logger}->warn("$binary is not a file but a bash builtin/alias/keyword");
		}
		
	}
	
	$self->absFilename( $binary);
	
}

# get the absolute filepath for the file
sub _getFullFile{
	my($self)=@_;
	
	my $file=$self->filename();
	if($self->type() eq 'asis'){
		$self->absFilename( $self->filename());
		return;
	}
	if($file =~/^s3:/){
	}else{
		$file=File::Spec->rel2abs( $file);
		
	}
	#$file=Cwd::abs_path( $file );
	$self->absFilename($file);
	
}


sub getTmpDir{
	my($self)=@_;
	my $tmpdir=$RealBin;
	if( defined($ENV{NGS_TMP_DIR})){
		$tmpdir= $ENV{NGS_TMP_DIR};
	}elsif( -d '/opt/scratch'){ 
		$tmpdir=  '/opt/scratch';
	}elsif( -d '/tmp'){
		$tmpdir=  '/tmp';
	}
	$self->{logger}->trace("getTmpDir: temporary directory set to $tmpdir");
	return $tmpdir;
}


sub getScheme{
	my($self)=@_;
	if(!defined($self->{uri})){return undef;}
	return $self->{uri}->scheme();
}

sub _setURI{
	my($self)=@_;
	my $filename=$self->filename();
	$self->{uri}=URI->new( $filename );
	if(!defined($self->{uri}->scheme())){
		$self->{uri}->scheme("file");
	}
	$self->{logger}->trace("_setURI: [$filename] belongs to scheme [", $self->{uri}->scheme() ,"]");

	if( $self->{uri}->scheme() eq 's3'){

		$self->{logger}->trace("_setURI: The provided URI ($filename) is an S3 object");
		# bring the file locally
		my $localFile=$self->{uri}->authority().$self->{uri}->path();
		$localFile= $self->getTmpDir."/$localFile";
		$self->{logger}->trace("_setURI: The path for this object is $localFile");
		my ($volume,$directories,$file) = File::Spec->splitpath( $localFile );
		$self->{logger}->info("_setURI: Creating a local copy of the file in $directories");
		make_path( $directories );
		my $returnCode=0;
		if( $self->{shadowFile} eq 'off'){
			my $cmd="$RealBin/s3-multipart/s3-mp-download.py -f -np 4 -s 10 ".$self->{uri}->as_string().' '.$localFile ;
			$self->{logger}->trace("_setURI: Executing $cmd");
			$returnCode=Celgene::Utils::CommonFunc::runCmd($cmd);
			$self->{logger}->trace("_setURI: Return code is $returnCode");
		}else{
			my $outFh= FileFunc::newWriteFileHandle( $localFile );
			print $outFh "SHADOW file of ". $self->userFileName()."\n";
			close($outFh);
		}
		$self->filename( $localFile);
		
		# remmeber if we downloaded this file from S3 or not
		if($returnCode != 0){
			$self->{downloadedFromS3}='false';
		}else{
			$self->{downloadedFromS3}='true';
		}
	}
	
	
}


1;
