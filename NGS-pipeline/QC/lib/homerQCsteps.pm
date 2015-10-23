package homerQCsteps;
use strict;
use warnings;
use Log::Log4perl;
use File::Basename;
use File::Spec;
use Celgene::Utils::FileFunc;
use Cwd;
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->{logger}=Log::Log4perl->get_logger("runQC::homerQCsteps");
    $self->binary( 'makeTagDirectory');
	#$self->refflat("/opt/reference/Homo_sapiens/GENCODE/hg19/Annotation/gencode.v14.refFlat"); #ensembl
    
    
    if(defined($ENV{ NGS_TMP_DIR })) {
    	$self->{tempDir}=$ENV{NGS_TMP_DIR};
    }else{
    	$self->{tempDir}=getcwd();
    }
    # depending on the reference genome one of these lines would be working:
    # TODO generate this file from the header of hte bam file
    # $self->ribosomalintervals("/opt/reference/Homo_sapiens/GENCODE/hg19/Annotation/gencode.v14.rRNA");
	#$self->ribosomalintervals("/opt/reference/Homo_sapiens/GENCODE/hg19/Annotation/gencode.v14.b.rRNA");
    return $self;
}
#call this function if the output files havealready been generated



sub DESTROY{
	my($self)=@_;
	my $session=$$;
}




sub reuse{
	my($self)=@_;
	$self->{reuse}=1;
}

sub binary{
	my($self,$bin)=@_;
	if(defined($bin)){
		$self->{binary}=$bin;
	}
	# we are searching for the binary file
	if(!defined($self->{binary})){
		
		$self->{logger}->logdie("The location of the the homer 'makeTagDirectory' is not specified");
		
	}
	return $self->{binary};
}

# this is actually the makeTagDirectory
sub outputDirectory{
	my($self,$fn)=@_;
	if(defined($fn)){
		$self->{logger}->debug("outputDirectory: output directory is set to $fn");
		$self->{outputdirectory}=$fn;
	}
	return $self->{outputdirectory};
}



sub genomeFile{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting genome version to $value");
		if( $value ne 'hg19' and $value ne 'hg38' ){$self->{logger}->logdie("Cannot find version $value")};
		$self->{genomeFile}=$value;
	}
	return $self->{genomeFile};
}

sub getVersion{
	my ($self)=@_;
	my $version='unknown';
	my $returnValue= "Homer [". $version."]";
	
	return $returnValue;

}

sub runHomerQC{
	my($self, $bamfile, $step)=@_;

	if( lc($step) eq 'homer'){ $self->runHomerQCMakeTagDirectory( $bamfile);}
	else{ $self->logger->warn( "Uknown QC step $step for homer")}
	
}
sub runHomerQCMakeTagDirectory{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);

	my $cmd=
	"makeTagDirectory ".$self->outputDirectory().
	" -format sam -genome ".$self->genomeFile.
	" -checkGC ". $bamfile;

	$self->{logger}->info("Running $cmd");
	Celgene::Utils::CommonFunc::runCmd($cmd) if(!defined($self->{reuse} ) );


}

sub parseFile{
	my($self, $bamfile,$step)=@_;
	$self->{logger}->debug("parseFile: now parsing file $bamfile for qcStep $step");
	if( lc($step) ne 'homer'){ return ;}

	my($filename, $directories, $suffix) = fileparse($bamfile);
	$self->{filename}=File::Spec->rel2abs($bamfile);
	# we need to parse the results from different files

    $self->{logger}->info("parseFile: Parsing ". $self->outputDirectory() );
	$self->parseAutocorrelation($self->outputDirectory() ); 
	$self->parseCountDistribution($self->outputDirectory() ); 
	#$self->parseFrequency($self->outputDirectory() ); 
	$self->parseGCContent($self->outputDirectory() ); 
	
}


sub parseGCContent{
	my($self,$dir)=@_;
	
	my @fnames=("tagGCcontent.txt", "genomeGCcontent.txt");
	foreach my $fname(@fnames){
		$self->{logger}->debug("parseGCContent: Parsing file $fname");
		my $fh=Celgene::Utils::FileFunc::newReadFileHandle( $dir."/".$fname);
		
		while(my $line=<$fh> ){
			chomp($line);
			if( $line =~/^GC%/){next;}
			my($gc, $total,$frac)=split("\t",$line);	
			if($fname eq 'tagGCcontent.txt'){
				push @{$self->{ tag_gc }}, $gc;
				push @{$self->{ tag_gc_total }}, $total;
			}else{
				push @{$self->{ genome_gc }}, $gc;
				push @{$self->{ genome_gc_total }}, $total;
			}
		}
		close($fh);
	}

	
}

sub parseAutocorrelation{
	my($self,$dir)=@_;
	
	my $fname="tagAutocorrelation.txt";
	my $fh=Celgene::Utils::FileFunc::newReadFileHandle( $dir."/".$fname);
	$self->{logger}->debug("parseAutocorrelation: Parsing file $fname");
	my @dis=();
	my @sameStrand=();
	my @oppositeStrand=();
	while(my $line=<$fh> ){
		chomp($line);
		if( $line =~/Fragment Length Estimate: (\d+)/){$self->{ fragment_length_estimate}=$1;}
		if( $line =~/Peak Width Estimate: (\d+)/){$self->{ peak_width_estimate}=$1;}
		if( $line =~/^Distance/){next;}
		my($distance, $same,$opposite)=split("\t",$line);	
		
		push @dis, $distance;
		push @sameStrand, $same;
		push @oppositeStrand, $opposite;
		
	}
	close($fh);
	$self->{ distance}=\@dis;
	$self->{ same_strand_count}=\@sameStrand;
	$self->{ opposite_strand_count}=\@oppositeStrand;
	
}


sub parseCountDistribution{
	my($self,$dir)=@_;
	
	my $fname="tagCountDistribution.txt";
	my $fh=Celgene::Utils::FileFunc::newReadFileHandle( $dir."/".$fname);
	
	my @position=();
	my @fraction=();

	while(my $line=<$fh> ){
		chomp($line);
		if( $line =~/Tags per tag position: (\d+)/){$self->{ median_tag_position }=$1;}
		if( $line =~/^Tags/){next;}
		my($pos, $frac)=split("\t",$line);	
		
		push @position, $pos;
		push @fraction, $frac;
		
	}
	close($fh);
	$self->{ tags_position}=\@position;
	$self->{ tags_per_position}=\@fraction;	
}

# decided not to use 
# htis information is partially provided by the GC distribution of reads by fastqc
#sub parseFrequency{
#	my($self,$dir)=@_;
#	
#	my $fname="tagFreq.txt";
#	my $fh=Celgene::Utils::FileFunc::newReadFileHandle( $dir."/".$fname);
#	
#	my @offset=();
#	my @labels=();
#	while(my $line=<$fh> ){
#		chomp($line);
#		if( $line =~/^Offset/){
#			@labels=split("\t",$line);
#			@labels=shift @labels;
#			$self->{tag_frequency_labels}=\@labels;
#			next;	
#		}
#		my($offset, @frac)=split("\t",$line);	
#		
#		push @{$self->{offset}}, $offset;
#		for( my $i=0; $i<scalar(@labels); $i++){
#			push @{$self->{ tag_frequency} }, \@frac;
#		}
#	}
#	close($fh);
#	
#}



1;
