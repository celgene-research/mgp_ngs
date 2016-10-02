package celgeneExec;
use strict;
use warnings;
use Celgene::Utils::FileFunc;
use Celgene::Utils::ArrayFunc;
use File::Spec;
use fileObj;
use Time::localtime;
use File::stat;
use threads;
use Exporter;

our @ISA =   qw(Exporter);
our @EXPORT = qw(checkFileVersion
getBinary getExistingFiles getNewFiles getPossibleFiles getVersion parseArguments parseSpecific setRunCommand splitCommand);



my $logger=Log::Log4perl->get_logger("celgeneExecFunc");
# check if there is any pipe symbol
# and return an array of the individual commands
sub splitCommand{
	my ($command)=@_;
	my @cmds;
	my @c1=split(";", $command); # split the command on the ';' 
	foreach my $c(@c1){
		my @c2=split(' \| ', $c);
		@cmds=(@cmds, @c2);
	}
#	$command =~s/\|\|/\*DOUBLESPLIT\*/g; # avoid parsing the logical OR
#	$command =~s/\\\|/\*ESCAPESPLIT\*/g; # avoid parsing escaped character
#	my @cmds=split(/[\|;]/, $command);
#	for(my $i=0;$i<scalar( @cmds );$i++){
#		$cmds[$i] =~s/\*DOUBLESPLIT\*/\|\|/g; # avoid parsing the logical OR
#		$cmds[$i] =~s/\*ESCAPESPLIT\*/\\\|/g; # avoid parsing escaped character
#	
#	}
	$logger->debug("The command was split to \n**       ", join("\n**       ",@cmds));
	return @cmds;
}


# parses the input command line, and tries to find specifi information for the program
# by checking for analysis_task and derived_from_list
sub parseArguments{
	my ($inputCmd, $hash)=@_;
	my @args=split(",", $inputCmd);
	foreach my $a(@args){
		if ($a =~/analysis_task=(\d+),?/ or $a =~/analysistask=(\d+),?/) {
			$hash->{analysis_task}= $1;
			$logger->debug("Command is executed under analysis task [$hash->{analysis_task}]");
		}
		if ($a =~/derived_from_list=(\S+),?/ or $a =~/derivedfromlist=(\S+),?/) {
			my $derivedFrom=$1;
			$logger->debug("Derived from files are found in file [$derivedFrom]");	
			my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($derivedFrom);
			
			while(my $l=<$rfh>){ 
				chomp $l; 
				push  @{$hash->{derived_from}}, $l;
			}
			close($rfh);
		}
	}


}


# combines interpreter and binary to an executable command
sub setRunCommand{
	my($binary,$interpreter)=@_;
	if(!defined($interpreter)){
		return $binary;
	}
	if($interpreter =~/java$/){
		return "$interpreter -jar $binary";
	}
	
	return "$interpreter $binary";
}

# get the binary that is used to execute the command
# attention is paid if we have java (or other interpreters) preceding the command
# input is the full command
sub getBinary{
	my($cmd,$userbinary)=@_;
	chomp $cmd;
	my $interpreter;
	$cmd=~/^\s*(.+)\s*$/; $cmd =$1;
	#find the executable
	my ($binary)=split(/\s+/, $cmd);
	#special case for calling explicit interpreters. Binary is becoming the java class or the script.
	if($binary =~/java$/){ 
		$cmd=~/(.+) -jar\s+(\S+)\s+(\S+)/; 
		$binary = $2;
		my $binary2=$3;
		# for picard tools which are called in the form 'picard.jar TOOL' 
		# and possibly other tools in the future, the actual binary is the combination
		# of the java class and its first argument 
		if($binary =~/picard.jar$/){
			$binary .=" ".$binary2;
		}
		$interpreter= 'java'
	};

	#docker is a more complicated case
	# it has a series of arguments with values eg -h <hostname> and the last two are the image and command
	if($binary =~/docker$/){
		if(!defined($userbinary) ){
			$logger->logdie("User submitted a docker container command, but not executable in the executable field of celgeneExec.pl");
		}
		my $idx=index( $cmd , $userbinary );
			
		if( $idx==-1){
			$logger->logdie("User submitted a docker container command, but the executable is not in the list");
		}
		
		$binary=substr( $cmd, 0, $idx)." ".$userbinary;
		#$binary =~s/docker\s+run//g;
		$interpreter='docker';
	}

	$logger->trace("Detected binary as $binary");
	$logger->trace("Detected interpreter as $interpreter")if defined($interpreter);
	$logger->trace("Starting object for binary '$binary'");
	my $binaryObj;
	if(defined($interpreter) and $interpreter eq 'docker'){
		$binaryObj= fileObj->new( $binary , "asis");
	}else{
		$binaryObj= fileObj->new( $binary , "binary");
	}
	$logger->trace("Starting object for interpreter '$interpreter'")if defined($interpreter);
	my $interpreterObj= fileObj->new($interpreter, "binary") if defined($interpreter);
	
	return ($binaryObj, $interpreterObj);
}

sub parseSpecific{
	my ($binaryObj,$interpreterObj,$hash ,$possibleFiles)=@_;
	
	# some command specific functions
	my $disp={
#		'bowtie2' => \&parsebowtie2,
#		'samtools' => \&parsesamtools,
#		'macs14'  => \&parseMACS,
#		'htseq-count' =>\&parseHTSeq,
#		'STAR' =>\&parseSTAR,
#		'cufflinks'=>\&parseCufflinks
	};
	if(defined($disp->{ $binaryObj->onlyFilename() }  )){
                $disp->{ $binaryObj->onlyFilename()  }->( $binaryObj,$interpreterObj,$hash);
	}

}

# parses the command and gets all tokens excluding the name of the program itself
sub getPossibleFiles{
	my ($cmdRef, $binaryObj,$interpreterObj)=@_;
	my @fileList=();
	# get all possible filenames from this command
	my @elements=split(/[\s\,\=]+/, $$cmdRef); shift @elements;
	$logger->trace("getPossibleFiles: getting all the possible files from tokens of the command line");
	foreach my $e(@elements){
		if($e=~/^[-><]/){next;}
		$e=~s/[()]//g;
		if(defined($binaryObj) and $e eq $binaryObj->filename() ){next;}
		if(defined($interpreterObj) and $e eq $interpreterObj->filename() ){next;}
		if($e eq "" ){next;}
		my $fileObj=fileObj->new( $e  , "regular");
		push @fileList, $fileObj;

		
	}
	my $output=checkRedirOutput($$cmdRef);
	if( $output ){ 
		$logger->trace("getPossibleFiles: $output is a file generated from a pipe");
		my $outputObj=fileObj->new( $output, "regular");

		push @fileList,$outputObj;
	}
	
	foreach my $fileObj( @fileList){
				# if we change the filename (i.e. modified it to replace URI)
		if($fileObj->filename() ne $fileObj->userFileName() ){
			
			$logger->trace("getPossibleFiles: Command line had to change because of [", $fileObj->userFileName(),"] which became [",$fileObj->filename(),"]");
			my ($b,$a)=($fileObj->userFileName(),$fileObj->filename());
			$$cmdRef=~s/$b/$a/;
			$logger->trace("getPossibleFiles: to ", $$cmdRef);
		}
	}
	return \@fileList;
	
}

sub getExistingFiles{
	my($possibleFiles, $hash ,$command)=@_;
	
	my @candidates=@$possibleFiles;
	
	foreach my $c( @candidates ){
		if( -e $c->absFilename() or -d $c->absFilename()  ){
			if(defined($c->getScheme() ) and $c->getScheme() eq 's3'){push @{ $hash->{derived_from}}, $c->userFileName();} # need it when the userFileName is from S3
			else{push @{ $hash->{derived_from}}, $c->absFilename(); }
			
			$hash->{ _usedfilename }->{$c->absFilename()}=1;
			
			# we also need to replace this file in the command line
			if(defined($command)){
				$command =~s/$c/$c->absFilename()/; 
			}
		}
	}
	if(defined($command)){return $command;}
}


sub getNewFiles{
	my($possibleFiles, $hash, $timeSnap) =@_;

	my @candidates=@$possibleFiles;
	# 
	
	
	foreach my $c( @candidates){
		if(defined($hash->{_usedfilename}->{ $c->absFilename() })){next;} #don't consider derived from files
		# checkif some of the output filenames correspond to file_roots and add the new files in the list of @candidates
		my $mask=$c->absFilename()."*";
		$logger->trace("getNewFiles: Mask for files is [$mask]");
		# get the listing of files that match the mask
		my @newFiles=glob($mask);
		if(scalar(@newFiles)>0){
			foreach my $n(@newFiles){ 
				# exclude any .met files from the list
				if($n=~/\.met$/){next;}
				$logger->trace("getNewFiles: identified possible new candidate [$n]");
				if($n eq $c->absFilename()){ next; }
				my $fobj=fileObj->new($n);
				push @candidates, $fobj;
			}
		}
	}
	@candidates=Celgene::Utils::ArrayFunc::unique(\@candidates);
	foreach my $c( @candidates){
		if(defined($hash->{_usedfilename}->{ $c->absFilename() })){next;} #don't consider derived from files
		if(!-e $c->absFilename and !-d $c->absFilename()){next;}
		# check if a file like that exists with date of creation after the timeSnap
		$logger->trace("getNewFiles: Getting the modification date of the file ",$c->absFilename()) ;
		my $fileStat=stat($c->absFilename());
		if(scalar(@$fileStat) ==0){
			 $logger->warn( "getNewFiles: Could not stat file ", $c->absFilename()," : $!"); 
		}
		my $modifiedTime= $fileStat->[9] ;
		$logger->trace("getNewFiles: The modification date is ",$modifiedTime);
		$logger->trace("getNewFiles: Comparing with initialization time ", $timeSnap);
		if( -e $c->absFilename() and $modifiedTime >= $timeSnap){
			push @{$hash->{output}}, $c;
		;} # the file was modified after the program started
		if( -d $c->absFilename() and $modifiedTime >= $timeSnap){
			push @{$hash->{output}}, $c;
		;} # this directory was modified after the program started		

	}
}


sub getVersion{
	my(  $hash, $binaryObj,$interpreterObj)=@_;
	my $runCommand=$binaryObj->absFilename();
	if(defined($interpreterObj)){ $runCommand= setRunCommand($binaryObj->absFilename(), $interpreterObj->absFilename());}
	# try different methods to find the version of the program
	$logger->trace("getVersion: Looking for version of command $runCommand");
	
	my $version= checkFileVersion( $runCommand); # check if version is stored in a file (maintained by us)
	
	if(!defined($version)){ $version=_parseVersion("$runCommand --version 2>&1", $binaryObj->onlyFileName());}
	if(!defined($version)){ $version=_parseVersion("$runCommand -version 2>&1", $binaryObj->onlyFileName());}
	if(!defined($version)){ 
		my $command="$runCommand -v 2>&1";
		my $thr=threads->create( '_parseVersion' , $command , $binaryObj->onlyFileName());
		sleep(3);
		if($thr->is_running()){ $thr->kill('KILL')->detach();}
		else{ $version=$thr->join();}

	}
	if(!defined($version)){ 
		my $command="$runCommand  2>&1";
		my $thr=threads->create( '_parseVersion' , $command , $binaryObj->onlyFileName());	
		# wait for few seconds
		sleep(3);
		if($thr->is_running()){ $thr->kill('KILL')->detach();}
		else{ $version=$thr->join();}
	}
	if(!defined($version)){$version="$runCommand unknown version";}
	$logger->trace("getVersion: version is $version");
	my $p1=$binaryObj->onlyFilename();
	my $p2=$binaryObj->absFilename();
	my $p3=$binaryObj->filename();
	$version=~s/$p2//;
	$version=~s/$p3//;
	$version=~s/$p1//;
	$version=~s/:/ /;
	$version=~/^\s*(.+)\s*$/;
	$version=~s/[<>]//g;
	$version=$p1."[".$1."]" if defined $1;
	push @{$hash->{generator_version}},$version;
}

# check if there is a $command.celgene-version file which contains the version string only
sub checkFileVersion{
	my($binary)=@_;
	my $version;
	$logger->trace("checkFileVersion: Looking for program version in $binary.celgene.version");
	if(-e $binary.".celgene.version"){
		my $inFh=Celgene::Utils::FileFunc::newReadFileHandle( $binary );
		my $versionLine=<$inFh>;
		close($inFh);
		$version=chomp $versionLine;
	}
	return $version;
}


# check if the command line contains a redirection symbol (>)
sub checkRedirOutput{
	my($cmd)=@_;
	if($cmd=~/\s>>\s+(\S+)/){
		return $1;
	}
	elsif($cmd=~/\s>\s+(\S+)/){
		return $1;

	}
	else{
		return undef;
	}
}



sub _parseVersion{
	my ($cmd, $binary)=@_;
	$binary=lc($binary);
	 $SIG{'KILL'} = sub { threads->exit(); };
	my $lastLine;
	my $lineCounter=0;
	my $returnVersion;
	$logger->debug("_parseVersion: Running command $cmd for binary $binary");
	foreach my $l( `$cmd`){
		chomp $l;
		$lineCounter ++;
		$lastLine=$l;
		$logger->debug("_parseVersion: checking line [$l]");
		if(lc($l) =~/$binary/ and lc($l)=~/v([0-9\.]+[a-z]*)/){
			my $v=$1;
			$returnVersion=$v;
			$logger->debug( "Decided that version is [$returnVersion]");
			last;
		}
		if(lc($l)=~/version(.+)/ and lc($l)!~/-version/  
			){
			my $v=$1;
			$returnVersion=$v;
			$logger->debug( "Decided that version is [$returnVersion]");
			last;
		}
		
	}
	if(!defined($returnVersion) and $lineCounter==1 and $lastLine=~/\d/){
		$returnVersion=$lastLine;
	}
	if(!defined($returnVersion)){return undef;}
	#format the return string of the function
	

	return $returnVersion;
}

1;
