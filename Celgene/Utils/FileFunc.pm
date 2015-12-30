package Celgene::Utils::FileFunc;
use strict;
use warnings;
use File::Basename;
use File::Spec;
use Log::Log4perl;
use Cwd;
my $logger=Log::Log4perl->get_logger("FileFunc");


# return the filename components
# file= the filename to process
# updir= tree junctions in the filepath to ignore
# eg. /opt/Medussa/NGS/Public/GSE111999/rawdata/file.fq.gz
# if updir=4 will return:
#     file.fq.gz GSE111999/rawdata  

sub fileNameParse{
	my($file,$updir)=@_;
	
	if(!defined($updir)){
		$updir=0;
		if(defined( $ENV{NGS_DATA_DIR})){
			my @directories=File::Spec->splitdir( $ENV{NGS_DATA_DIR} );
			$updir=scalar(@directories) + 1;
		}
	}
	$logger->debug("fileNameParse: file [$file], discard the [$updir] lower directory nodes");
	# form the absolute path
	my $absPath="";
	if( File::Spec->file_name_is_absolute( $file )){ $absPath=$file;}
	else{ $absPath= File::Spec->rel2abs($file); }
	# make sure there are not ../ directories in the absolute path
	my @dirs=File::Spec->splitdir( $absPath );
	
	for(;;){
		my $mod=0;
	for(my $i=0; $i<scalar(@dirs);$i++){
		if( $dirs[$i] eq '..' ){
			splice( @dirs, $i -1 , 2);
			$mod++;
			last;
		}	
	}
		if($mod ==0){last;}
	}
	my $ftemp=pop( @dirs);
	$absPath=File::Spec->catfile( @dirs, $ftemp);
	$logger->debug("The absolute path is [$absPath]");
	
	
	
	####
	# parse the file
	my($fname,$directory,$suffix)=fileparse($absPath);
	my @directories=File::Spec->splitdir( $directory );
	#$logger->debug("The list of directories for $fname | $directory | $suffix is ", join(" | ", @directories));
	###
	# recreate the information we need
	
	$directory=File::Spec->catdir( @directories[ $updir .. (scalar(@directories)-1) ]);
	$logger->debug("The directory listing wanted is [$directory] \n\tcoming from entries [$updir] to [", scalar(@directories)-1,"]");
	return($fname,$directory,$suffix);
	
}


sub newReadFileHandle{
	my ($fn)=@_;
	my $fh;
	if($fn eq '-'){
		$fh= \*STDIN;
	}elsif( $fn =~/\.gz$/){
		open($fh, "gunzip -c $fn|") or $logger->logdie("Cannot open file $fn for reading\n");
	}elsif( $fn =~/\.bz2$/){
		open($fh, "bzcat  $fn|") or $logger->logdie("Cannot open file $fn for reading\n");
	}
	else{
		open($fh, $fn) or $logger->logdie("Cannot open file $fn for reading\n");
		
	}
	return($fh);
}

sub newWriteFileHandle{
	my ($fn)=@_;
	my $fh;
	if($fn eq '-'){
		$fh= \*STDOUT;
	}else{
		open($fh, ">".$fn) or $logger->logdie("Cannot open file $fn for writting\n");
	}
	return($fh);
}
sub newAppendFileHandle{
	my ($fn)=@_;
	my $fh;
	if($fn eq '-'){
		$fh= \*STDOUT;
	}else{
		open($fh, ">>".$fn) or $logger->logdie("Cannot open file $fn for appending\n");
	}
	return($fh);
}
1;
