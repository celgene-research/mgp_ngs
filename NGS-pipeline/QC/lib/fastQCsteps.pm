package fastQCsteps;
use strict;
use warnings;
use Celgene::Utils::CommonFunc;
use Celgene::Utils::FileFunc;
use File::Basename;
use FindBin '$Bin';
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->{logger}=Log::Log4perl->get_logger("runQC::fastQC");
    
    return $self;
}
sub binary{
	my($self,$bin)=@_;
	if(defined($bin)){
		$self->{binary}=$bin;
	}elsif(!defined($bin) and !defined($self->{binary}) ) {
		$self->{binary}= "/usr/local/bin/fastqc";
	}
	# we are searching for the binary file
	if(!defined($self->{binary}) ){
		$self->{logger}->logdie("The location of the fastqc binary is not specified");
	}
	if(! -e $self->{binary}  ){
		$self->{logger}->logdie("The location of the fastqc binary [$self->{binary}] is not correct ");
	}
	return $self->{binary};
}
sub binaryTrimmer{
	my($self,$bin)=@_;
	if(defined($bin)){
		$self->{binary_trimmer}=$bin;
	}elsif(!defined($bin) and !defined($self->{binary}) ) {
		$self->{binary_trimmer}= "/usr/local/bin/cutadapt";
	}
	# we are searching for the binary file
	if(!defined($self->{binary_trimmer}) ){
		$self->{logger}->logdie("The location of the trimmomatic binary is not specified");
	}
	if(! -e $self->{binary_trimmer}  ){
		$self->{logger}->logdie("The location of the trimmomatic binary [$self->{binary_trimmer}] is not correct ");
	}

	return $self->{binary_trimmer};
}
sub binaryLaneDistribution{
	my($self,$bin)=@_;
	if(defined($bin)){
		$self->{binary_lanedistr}=$bin;
	}elsif(!defined($bin) and !defined($self->{binary}) ) {
		$self->{binary_lanedistr}= "/usr/local/bin/cutadapt";
	}
	# we are searching for the binary file
	if(!defined($self->{binary_lanedistr}) ){
		$self->{logger}->logdie("The location of the trimmomatic binary is not specified");
	}
	if(! -e $self->{binary_lanedistr}  ){
		$self->{logger}->logdie("The location of the trimmomatic binary [$self->{binary_lanedistr}] is not correct ");
	}

	return $self->{binary_lanedistr};
}
sub reuse{
	my($self)=@_;
	$self->{reuse}=1;
}
sub mapper{
	my($self)=@_;
	$self->{mapper}=1;
}
sub outputDirectory{
	my($self,$dir)=@_;
	if(defined($dir)){
		$self->{outputdir}=$dir ."/";
		my $cmd="mkdir -p ". $self->{outputdir};
		Celgene::Utils::CommonFunc::runCmd( $cmd );
	}
	return $self->{outputdir};
}

# create the results file/directory for fastqc


sub resultsFile{
	my($self, $infile)=@_;
	
	my($filename, $directories, $suffix) = fileparse($infile);
	$filename=~s/\.gz$//; # remove extension gz if present
	$filename=~s/\.bz2$//; # remove extension bz2 if present
	$filename=~s/\.zip$//; # remove extension zip if present
	$filename=~s/\.fastq$//; #remove fastq if present
	$filename=~s/\.fq$//; #remove fq if present
	#filename now contains only the name of the run (withoug extenstions)
	
	my $outdir=$self->outputDirectory();
	my $mask=$outdir."/".$filename."*_fastqc";
	$self->{logger}->info("Looking for output in $outdir");
	opendir(my $dirh , $outdir) or $self->{logger}->logdie("Cannot access directory $outdir.".
	"This could mean that either the directory does not exist or the algorithm to predicted the name is not accurate");
	my @filenamesInDirectory=readdir( $dirh );
	closedir($dirh);
	if(scalar(@filenamesInDirectory)==0){
		$self->{logger}->logdie("Cannot find any relevant directory in $mask for this run");
	}
	my $resultdir;
	foreach my $f(@filenamesInDirectory){
		$self->{logger}->debug("Checking if $f satisfies the criteria to be considered the target directory [$filename] [_fastqc]");
		if( $f=~/^$filename(\S*)_fastqc$/){
			$resultdir= $f;
			last;
		}
	}
	if(!defined($resultdir)){
		$self->{logger}->warn("Cannot find existing results for $infile. Rerun without --reuse option.");
	}
	
	my $result=$resultdir ."/fastqc_data.txt";
	return $self->outputDirectory().$result;

}


# this sets the filename for the methods that create a file output
# and the output directory for hte fastQC 
sub outputFile{
	my ($self, $filename)=@_;
	if(defined($filename)){
		$self->{outputfile}=$filename;
	}
	return $self->{outputfile};
}

# provide the input file(s).
# this function creates a pipe to which directs all the files
# provided as input
# 
sub _inputFile{
	my($self,$inFile)=@_;
	if(defined($inFile)){
		
		$self->{inputFile}=$inFile;
	}
	return $self->{inputFile};
}

sub runFastqQC{
	my($self, $fq1,$fq2,$step)=@_;
	if(lc($step) eq 'fastqc'){
		$self->outputDirectory( $self->outputFile() );
		$self->runFastQC( $fq1, $fq2);
	}
	elsif(lc($step) eq 'lanedistribution'){
		$self->runLaneDistribution( $fq1 );
	}
	elsif(lc($step) eq 'adapter'){
		$self->runAdapter( $fq1, $fq2)	
	}

	else{
		$self->{logger}->logdie("Unknown fastq QC module [$step]");
	}
	
}



sub runFastQC{
	my($self, $fastqfile1,$fastqfile2)=@_;
	$self->{logger}->debug("Running fastq QC commands");
	if($fastqfile1=~/R2/ and $fastqfile2=~/R1/){
		$self->{logger}->logdie("The fastq files [$fastqfile1], [$fastqfile2] seem to have been entered in the wrong order");
	}
	my @a=( $fastqfile1 );
	if(defined($fastqfile2)){
		push @a, $fastqfile2;
	}
	
	foreach my $fastqfile (@a){
		# run fastqc
		my $cmd2=$self->binary(). " --outdir ". $self->outputDirectory() ." --nogroup ". $fastqfile;
		$self->{logger}->debug("Executing command $cmd2");
		if(defined($self->{reuse})){
			$self->{logger}->debug("The fastqc command has run in the past. The output is in ", $self->outputDirectory());
		}else{
				Celgene::Utils::CommonFunc::runCmd( $cmd2 ) ;
				$self->{logger}->debug("The fastqc command run. The output is in ", $self->outputDirectory());
		}
	}
	

	
}


sub runLaneDistribution{
	my($self, $fastqfile)=@_;
	$self->{logger}->debug("Running fastq QC commands");
		
	# run the librarydistribution
	my $cmd3=$Bin. "/getLibraryDistribution.pl ".$fastqfile ." ". $self->outputFile();
	$self->{logger}->debug("Executing command $cmd3");
	if(defined($self->{reuse})){
		$self->{logger}->debug("The fastqc command has run in the past. The output is in ", $self->outputDirectory());
	}else{
		Celgene::Utils::CommonFunc::runCmd( $cmd3 ) ;
		$self->{logger}->debug("The fastqc command run. The output is in ", $self->outputDirectory());
	}
}


sub _loadAdapters{
	my($self,$type)=@_;
	# load the adapters from the trimmomatic file
	my $filename;
	if($type eq 'SE'){
		if($self->technology() eq 'TruSeq2'){  
			$filename= 'TruSeq2-SE.fa';
		}
		if($self->technology() eq 'TruSeq3'){  
			$filename= 'TruSeq3-SE.fa';
		}
	}
	if($type eq 'PE'){  
		if($self->technology() eq 'TruSeq2'){
			$filename= 'TruSeq2-PE.fa';
		}
		if($self->technology() eq 'TruSeq3'){
			$filename= 'TruSeq3-PE.fa';
		}
	}
	
	$self->{ PE }=$type;	
	
	my $inFn=Celgene::Utils::FileFunc::newReadFileHandle( "$FindBin::RealBin/adapters/$filename");
	while(my $header=<$inFn>){
		my $sequence=<$inFn>;
		chomp $header;chomp $sequence;
		if($header !~/Prefix/ and $header !~/TruSeq/ ){next;} # keep only the prefixes (i.e. ignore PCR primers)
		if($header=~/>\S+\/2/){
			push @{ $self->{adapters}->{reverse} }, $sequence;
		}else{
			push @{ $self->{adapters}->{forward} }, $sequence;
		}
	}
	close($inFn);
		
	
}

sub runAdapter{
	my($self, $fastqfile1,$fastqfile2)=@_;
	$self->{logger}->debug("Running fastq QC commands");
	if($fastqfile1=~/R2/ and $fastqfile2=~/R1/){
		$self->{logger}->logdie("The fastq files [$fastqfile1], [$fastqfile2] seem to have been entered in the wrong order");
	}
	my @a=( $fastqfile1 );
	if(defined($fastqfile2)){
		push @a, $fastqfile2;
		$self->_loadAdapters('PE');
	}else{
		$self->_loadAdapters('SE');
	}
	
	
	
	for(my $i=0;$i<scalar(@a);$i++){
		my $fastqfile = $a[$i];
		my $cmd4=$self->binaryTrimmer(). " -o /dev/null " ;
		if($self->{PE} eq 'PE'){
			if($fastqfile =~/R1/){
				foreach my $adapter( @{$self->{adapters}->{forward}}){$cmd4.=" -a ".$adapter;}
			}
			elsif($fastqfile =~/R2/){
				foreach my $adapter( @{$self->{adapters}->{reverse}}){$cmd4.=" -a ".$adapter;}
			}
		}else{
			foreach my $adapter( @{$self->{adapters}->{forward}}){$cmd4.=" -a ".$adapter;}
		}
		my $redir =">";
		if($i==1){$redir ='>>';}
		$cmd4.=" ".$fastqfile ." &".$redir." ". $self->outputFile();
		$self->{logger}->debug("Executing command $cmd4");
		if(defined($self->{reuse})){
			$self->{logger}->debug("The trimmer command has run in the past. The output is in ", $self->outputFile() );
		}else{
			
			Celgene::Utils::CommonFunc::runCmd( $cmd4 ) ;
			$self->{logger}->debug("The trimmer command run. The output is in ", $self->outputFile());
		}
	}
	

	
}


sub getVersion{
	my ($self)=@_;
	my @returnValue;
	my $cmd=$self->binary(). " --version ";
	my $version= `$cmd`;
	push @returnValue, $version;
	return @returnValue;
}

sub parseFile{
	my($self,$fastqfile1,$fastqfile2,$step)=@_;
	
	if(lc($step) eq 'fastqc'){
		$self->parseFastQC( $fastqfile1 );
		$self->parseFastQC( $fastqfile2);
	}
	elsif( lc($step) eq 'lanedistribution'){
		$self->parseLaneDistribution( $fastqfile1 );
	}
	elsif( lc($step) eq 'adapter'){
		$self->parseTrimmer();
	}
	else{ $self->{logger}->logdie("Cannot recognize QC module [$step]");}
}

{my $index=0;
sub parseFastQC{
	my($self, $file)=@_;
	$self->{rfh}=Celgene::Utils::FileFunc::newReadFileHandle( $self->resultsFile( $file ) );
	$self->{logger}->info("Parsing file ", $self->resultsFile($file) );
	my $rfh=$self->{rfh};
	while(my $line=<$rfh>){
		chomp $line;
		
		if($line =~/>>Basic Statistics/){
			$self->parseBasicStatistics($index );
		}
		if($line=~/>>Per base sequence quality/){
			$self->parseBaseQuality($index);
		}
		if($line=~/>>Per base sequence content/ or 
		   $line=~/>>Per base GC content/){
			$self->parseBaseGC($index);
		}
		if($line=~/>>Per base N content/){
			$self->parseBaseN($index);
		}
	}
	close($self->{rfh} );
	$index++;
}}

# this parser needs to run only for one of the two mate pairs 
sub parseLaneDistribution{
	my($self)=@_;
	$self->{logger}->info("Parsing file ", $self->outputFile() );
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle(   $self->outputFile() );

	$self->{lanes}=[];
	$self->{lanes_reads}=[];
	while(my $line=<$rfh>){
		
		chomp $line;
		if($line=~/^LANE\t(\S+)\tREADS\t(\d+)/){
			my ($lane,$reads)=($1,$2);
			push @{$self->{lanes}}, $lane;
			push @{$self->{lanes_reads}}, $reads;
		}
		
	}
	close($rfh);
}
sub technology{
	my($self,$tech)=@_;
	if(defined($tech)){
		# the definitions for truseq2 or truseq3 comes from the trimmomatic manual
		if($tech =~/HiSeq/ or $tech =~/MiSeq/){$self->{technology}='TruSeq3';}
		elsif($tech=~/Genome Analyzer/){ $self->{technology}='TruSeq2';}
		else{ $self->{logger}->logdie("I do not know how to handle the provided technology [$tech] ");}
	}
	
	$self->{logger}->debug("The provided technology was translated to ". $self->{ technology });
	return $self->{technology};
}
# this is the parser for cutadapt prior to 1.8 
# after 1.8 cutadapt supports parallel processing of paired end reads
#sub parseTrimmer{
#	
#	my ($self)=@_;
#	$self->{logger}->info("Parsing file ", $self->outputFile() );
#	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle(  $self->outputFile() );
#	foreach my $index(1,2){
#		$self->{adapter}->[$index]="";
#		$self->{trimming_events}->[$index]=0;
#		$self->{trimmed_reads}->[$index]=0;
#		$self->{trimmed_bases}->[$index]=0;
#		$self->{too_short_reads}->[$index]=0;
#		$self->{too_long_reads}->[$index]=0;
#		$self->{trimmed_length}->[$index]=[];
#		$self->{trimmed_count }->[$index]=[];
#		$self->{trimmed_expected}->[$index]=[];
#	}
#	my $index=-1;
#	while(my $line=<$rfh>){
#		chomp $line;
#		if($line =~/Command line parameters/){ $index ++;}
#		if($line=~/Adapter \'(\S+)\', length/){ $self->{adapter}->[$index]=$1;}
#		if($line=~/was trimmed (\d+) times/){ $self->{trimming_events}->[$index]=$1;}
#		if($line=~/Trimmed reads:\s+(\d+)/){ $self->{trimmed_reads}->[$index]=$1;}
#		
#		if($line=~/Trimmed bases:\s+(\d+)/){ $self->{trimmed_bases}->[$index]=$1;}
#		if($line=~/Too short reads:\s+(\d+)/){ $self->{too_short_reads}->[$index]=$1;}
#		if($line=~/Too long reads:\s+(\d+)/){ $self->{too_long_reads}->[$index]=$1;}
#		if($line=~/length	count	expect/){
#			while(my $line2=<$rfh>){
#				chomp $line2;
#				last if ($line2 eq"" or $line2 =~/cutadapt version/);
#				my($length,$count,$expected)=split("\t", $line2);
#				$expected=int($expected);
#				push @{$self->{trimmed_length}->[$index]}, $length;
#				push @{$self->{trimmed_count }->[$index]}, $count;
#				push @{$self->{trimmed_expected}->[$index]},$expected;
#		
#				
##				if($index==1 and 
##					scalar( @{$self->{trimmed_length}->[$index-1]}  ) < scalar(   @{$self->{trimmed_length}->[$index]})){
##					push @{$self->{trimmed_length}->[$index-1]}, -1;
##					push @{$self->{trimmed_count }->[$index-1]}, -1;
##					push @{$self->{trimmed_expected}->[$index-1]},-1;
##				}
#			}
#		}
#	}
#	# make sure that the arrays in for trimmed_length, trimmed-count, trimmed_expected have the same length
#	$self->_normalizeArrays( $self->{trimmed_length}->[0], $self->{trimmed_length}->[1], -1);
#	$self->_normalizeArrays( $self->{trimmed_count}->[0], $self->{trimmed_count}->[1], -1);
#	$self->_normalizeArrays( $self->{trimmed_expected}->[0], $self->{trimmed_expected}->[1], -1);
#	close($rfh);
#	$index ++;
#}

# new parser for cutadapt > 1.8 which supports paired end reads
sub parseTrimmer{
	
	my ($self)=@_;
	$self->{logger}->info("Parsing file ", $self->outputFile() );
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle(  $self->outputFile() );
	foreach my $index(0,1){
		$self->{adapter}->[$index]="";
		$self->{trimming_events}->[$index]=0;
		$self->{trimmed_reads}->[$index]=0;
		$self->{trimmed_bases}->[$index]=0;
		$self->{quality_trimmed_bases}->[$index]=0;
		$self->{too_short_reads}->[$index]=0;
		$self->{too_long_reads}->[$index]=0;
		$self->{trimmed_length}->[$index]=[];
		$self->{trimmed_count }->[$index]=[];
		$self->{trimmed_expected}->[$index]=[];
	}
	my $index=-1;
	my $flag;
	while(my $line=<$rfh>){
		chomp $line;
		# parse general information from the summary section
		# for read 1 and read 2 of a paired end experiment
		if($line =~/Read (\d) with adapter:\s+(\S+)/){
			my $idx=$1;
			$idx--; # We want the index to be 0 to 1 
			my $bps=$2;$bps=~tr/,//d;
			$self->{trimmed_reads}->[ $idx ]=$bps ;
		}
		# for all reads in a SE experiment
		if($line =~/Reads with adapters:\s+(\S+)/){
			my $idx=0;
			my $bps=$1;$bps=~tr/,//d;
			$self->{trimmed_reads}->[ $idx ]=$bps ;
		}
		if ($line =~/^Total basepairs processed/){ $flag="total";}
		if ($line =~/^Quality trimmed/){ $flag="quality";}
		if ($line =~/^Total written/){ $flag="written";}
		if($line =~/Read (\d):\s+(\S+) bp/){
			my ($idx,$bps)=($1,$2); $bps=~tr/,//d;
			$idx--;
			if( $flag eq 'total' ){
				$self->{trimmed_bases}->[$idx] = $bps; # load the total number of bases
			}
			if( $flag eq 'quality'){
				$self->{quality_trimmed_bases}->[$idx] = $bps; # subtract the quality trimmed bases
			}
			if( $flag eq 'written'){
				$self->{trimmed_bases}->[$idx] -= $bps; # subtract the written bases and get the adaptor trimmed bases
				$self->{trimmed_bases}->[$idx] -= $self->{quality_trimmed_bases}->[$idx];
			}
		}
	
	
	
		if($line =~/First read:/){ $index =0;}
		if($line =~/Second read:/){ $index =1;}
		if($line=~/Sequence: (\S+); Type/){ $self->{adapter}->[$index]=$1;}
		if($line=~/Trimmed: (\d+) times/){ $self->{trimming_events}->[$index]+=$1;}
		
		#this is not reported by cutadapt but remains here for compatibility
		if($line=~/Too short reads:\s+(\d+)/){ $self->{too_short_reads}->[$index]=$1;}
		if($line=~/Too long reads:\s+(\d+)/){ $self->{too_long_reads}->[$index]=$1;}
		
		if($line=~/length	count	expect/){
			while(my $line2=<$rfh>){
				chomp $line2;
				last if ($line2 eq"" or $line2 =~/cutadapt version/);
				my($length,$count,$expected)=split("\t", $line2);
				$expected=int($expected);
				push @{$self->{trimmed_length}->[$index]}, $length;
				push @{$self->{trimmed_count }->[$index]}, $count;
				push @{$self->{trimmed_expected}->[$index]},$expected;
		
				
#				if($index==1 and 
#					scalar( @{$self->{trimmed_length}->[$index-1]}  ) < scalar(   @{$self->{trimmed_length}->[$index]})){
#					push @{$self->{trimmed_length}->[$index-1]}, -1;
#					push @{$self->{trimmed_count }->[$index-1]}, -1;
#					push @{$self->{trimmed_expected}->[$index-1]},-1;
#				}
			}
		}
	}
	# make sure that the arrays in for trimmed_length, trimmed-count, trimmed_expected have the same length
	$self->_normalizeArrays( $self->{trimmed_length}->[0], $self->{trimmed_length}->[1], -1);
	$self->_normalizeArrays( $self->{trimmed_count}->[0], $self->{trimmed_count}->[1], -1);
	$self->_normalizeArrays( $self->{trimmed_expected}->[0], $self->{trimmed_expected}->[1], -1);
	close($rfh);
	$index ++;
}



sub _normalizeArrays{
	my($self, $array1, $array2, $default)=@_;
	if(!defined($default)){$default=-1;}
	my $m=0;my $s=0;
	if(scalar(@$array1)== scalar(@$array2)){return;}
	if(scalar(@$array1) > scalar(@$array2)){ $m=scalar(@$array1), $s=scalar(@$array2);}
	else{$m=scalar(@$array2);$s=scalar(@$array1);}
	for(my $k=$s; $k<$m ; $k++){
		if(!defined($array1->[$k])){$array1->[$k]=$default;}
		if(!defined($array2->[$k])){$array2->[$k]=$default;}
	}
}

sub parseBaseN{
	my($self,$index)=@_;
	my $rfh=$self->{rfh};
	$self->{N}->[$index]=[0];
	while(my $line=<$rfh>){
		chomp $line;
		if($line =~/>>END_MODULE/){
			last;
		}
		if($line=~/#/){next;}
		my($base,$GC)=split("\t",$line);
		$base--;
		$self->{N}->[$index]->[$base]=int($GC * 100);
	}
	return;
}

sub parseBaseGC{
	my($self,$index)=@_;
	my $rfh=$self->{rfh};
	$self->{GC}->[$index]=[0];
	while(my $line=<$rfh>){
		chomp $line;
		if($line =~/>>END_MODULE/){
			last;
		}
		if($line=~/#/){next;}
		my($base,@GC)=split("\t",$line);
		$base--;
		#older Fastqc output
		if( scalar(@GC) < 4 ){
			$self->{GC}->[$index]->[$base]=int($GC[0]);
		}else{
			# newer fastqc output. they have %ages for each base separately
			$self->{GC}->[$index]->[$base]=int( $GC[0] + $GC[3] );
			
		}
		if( $self->{GC}->[$index]->[$base] eq 'nan'   ){
			$self->{GC}->[$index]->[$base]=0;
		}
	}
	return;
}

sub parseBaseQuality{
	my($self,$index)=@_;
	my $rfh=$self->{rfh};
	$self->{mean}->[$index]=[0];
	$self->{median}->[$index]=[0];
	$self->{lowerquartile}->[$index]=[0];
	$self->{upperquartile}->[$index]=[0];
	$self->{tenpercentile}->[$index]=[0];
	$self->{ninetypercentile}->[$index]=[0];
	while(my $line=<$rfh>){
		chomp $line;
		if($line =~/>>END_MODULE/){
			last;
		}
		if($line=~/#/){next;}
		my($base,$mean,$median,$lQuartile,$uQuartile,$lPercentile,$uPercentile)=split("\t",$line);
		$base--;
		$self->{mean}->[$index]->[$base]=int($mean);
		$self->{median}->[$index]->[$base]=int($median);
		$self->{lowerquartile}->[$index]->[$base]=int($lQuartile);
		$self->{upperquartile}->[$index]->[$base]= int($uQuartile);
		$self->{tenpercentile}->[$index]->[$base]= int($lPercentile);
		$self->{ninetypercentile}->[$index]->[$base]= int($uPercentile);
		
		
	}
	return;
}

sub parseBasicStatistics{
	my($self,$index)=@_;
	my $rfh=$self->{rfh};

	while(my $line=<$rfh>){
		chomp $line;
		if($line =~/^#/){next;}
		if($line =~/>>END_MODULE/){
			last;
		}
		if($line=~/Total Sequences	(\d+)/){
			$self->{totalsequences}->[$index]=$1;
			$self->{logger}->debug("Found ". $self->{totalsequences}->[$index]. " sequences");
		}	
		if($line=~/Sequence length	(\d+)/){
			$self->{sequencelength}->[$index]=$1;
			$self->{logger}->debug("Found ". $self->{sequencelength}->[$index]. " sequence length");
		}	
		if($line=~/Encoding	(.+)/){
			$self->{encoding}->[$index]=$1;
			$self->{logger}->debug("Found ". $self->{encoding}->[$index]. " encoding");
		}
	
	}
	return;
	
}

1;
