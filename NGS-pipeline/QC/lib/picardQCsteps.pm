package picardQCsteps;
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
    
    $self->{logger}=Log::Log4perl->get_logger("runQC::picardQCsteps");
    $self->binary( $ENV{PICARD_BASE});
    $self->strandness( "NONE") ;
    $self->{makeDictAndExit}="no";
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
		
		$self->{logger}->logdie("The location of the PICARD_TOOLS is not specified");
		
	}
	return $self->{binary};
}
sub mateReads{
	my($self, $value)=@_;
	if(defined($value) ){
		$self->{mateReads}=$value;
	}
	return $self->{mateReads};
}
sub outputFile{
	my($self,$fn)=@_;
	if(defined($fn)){
		$self->{logger}->debug("outputFile: output file is set to $fn");
		$self->{outputfile}=$fn;
	}
	return $self->{outputfile};
}
sub outputFile2{
	my ($self,$insert)=@_;
	if(!defined($insert)){return $self->outputFile();}
	my @ar= split(/\./, $self->{outputfile} );
	$ar[-1]=$insert.".".$ar[-1];
	return join('.' , @ar);
	
	
}

sub strandness{
	my ($self,$value)=@_;
	if(defined($value)){
		
		# strand can be 'NONE', 'CONVERGE', 'DIVERGE'
			if(lc($value) eq 'none'){$value='NONE';}
			elsif(lc($value) eq 'forward'){$value='FIRST_READ_TRANSCRIPTION_STRAND';}
			elsif(lc($value) eq 'reverse'){$value ='SECOND_READ_TRANSCRIPTION_STRAND'}
			else{ $self->{logger}->logdie("Unrecognized strandness $value");}
		$self->{strandness}=$value;
	}
	return $self->{strandness};
}



sub genomeFile{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting genomeFile to $value");
		if(!-e $value){$self->{logger}->logdie("Cannot find file $value")};
		$self->{genomeFile}=$value;
	}
	return $self->{genomeFile};
}

sub getVersion{
	my ($self)=@_;
	my $program= "MarkDuplicates.jar";
	my $cmd=
	"java  -Xmx1g -jar " . $self->binary(). "/". $program.
	" --version 2>&1"; 
	my $version;
	if(!defined($self->{reuse})){
		
		$version=`$cmd` ;
		chomp $version;
	}else{
		$version = "n/a reused file";
	}
	my $returnValue= "Picard tools [". $version."]";
	
	return $returnValue;

}

sub runPicardQC{
	my($self, $bamfile, $step)=@_;
	if( lc($step) eq 'markduplicates'){ $self->runPicardQCMarkDuplicates($bamfile);}
	if( lc($step) eq 'librarycomplexity' or
		lc($step) eq 'librarycomplexitynorna'){ $self->runPicardQCEstimateLibraryComplexity($bamfile);}
	if( lc($step) eq 'collectrnaseqmetrics'){ $self->runPicardQCCollectRNASeqMetrics($bamfile);}
	if( lc($step) eq 'collectinsertsize'){ $self->runPicardQCInsertSize($bamfile);}
	if( lc($step) eq 'collectalnsummary'){ $self->runPicardQCAlignmentSummaryMetrics( $bamfile);}
	if( lc($step) eq 'bamindex'){ $self->runPicardQCBamIndex( $bamfile);}
	
}
sub runPicardQCBamIndex{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx2g';
	my $tempDir=' TMP_DIR='. $self->{tempDir};
	# run a set of picard tools to get an idea of the quality of datadf
	
	my $cmd4=
	"java $javaMemory -jar ". $self->binary()."/BamIndexStats.jar ".
	"VERBOSITY=WARNING ".
	"I=$bamfile ".
	$tempDir." ".
	"VALIDATION_STRINGENCY=SILENT > ".$self->outputFile();

	$self->{logger}->info("Running $cmd4");
	Celgene::Utils::CommonFunc::runCmd($cmd4) if(!defined($self->{reuse} ) );


}

sub runPicardQCAlignmentSummaryMetrics{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx2g';
	my $tempDir=' TMP_DIR='.  $self->{tempDir} ;
	# run a set of picard tools to get an idea of the quality of datadf
	
	my $cmd3=
	"java -client $javaMemory -jar ". $self->binary()."/CollectAlignmentSummaryMetrics.jar ".
	"I=$bamfile ".
	"O=".$self->outputFile()." ".
	$tempDir." ".
	"R=".$self->genomeFile()." ".
	"VERBOSITY=WARNING ".
	"VALIDATION_STRINGENCY=SILENT ";

	
	$self->{logger}->info("Running $cmd3");
	Celgene::Utils::CommonFunc::runCmd($cmd3)if(!defined($self->{reuse} ) );
			
}

sub runPicardQCInsertSize{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx8g';
	my $tempDir=' TMP_DIR='. $self->{tempDir};
	# run a set of picard tools to get an idea of the quality of datadf
	my $cmd1=
	"java -client  $javaMemory -jar " . $self->binary(). "/CollectInsertSizeMetrics.jar ".
	"VERBOSITY=WARNING ".
	"I=$bamfile ".
	"H=".$self->outputFile().".pdf " .
	"LEVEL=ALL_READS ".
	$tempDir." ".
	"O=".$self->outputFile()." ".
	"R=".$self->genomeFile()." ".
	"VALIDATION_STRINGENCY=SILENT "; 

	
	
	if($self->{mateReads} eq 'true'){
		$self->{logger}->info("Running $cmd1");
		Celgene::Utils::CommonFunc::runCmd($cmd1)if(!defined($self->{reuse} ) ); # insert size
	}


}


sub runPicardQCCollectRNASeqMetrics{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx4g';
	my $tempDir=' TMP_DIR='.  $self->{tempDir};
	# run a set of picard tools to get an idea of the quality of datadf


	$self->createDictionary($bamfile)if(!defined($self->{reuse} ) );
	my $cmd2=
	"java -client $javaMemory -jar " .$self->binary()."/CollectRnaSeqMetrics.jar ".
	"VERBOSITY=WARNING ".
	"REF_FLAT=".$self->refflat()." ".
	"RIBOSOMAL_INTERVALS=". $self->ribosomalintervals(). " ".
	"CHART=".$self->outputFile().".pdf ".
	"LEVEL=ALL_READS ".
	"I=$bamfile  ".
	$tempDir." ".
	"O=".$self->outputFile()." ".
	"STRAND_SPECIFICITY=". $self->strandness()." ".
	"VALIDATION_STRINGENCY=SILENT";
	$self->{logger}->debug("Command to execute: $cmd2");
	
	
	$self->{logger}->info("Running $cmd2");
	Celgene::Utils::CommonFunc::runCmd($cmd2)if(!defined($self->{reuse} ) );
			


}


sub runPicardQCMarkDuplicates{
	my($self, $bamfile)=@_;

	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx50g';
	my $tempDir=' TMP_DIR='.  $self->{tempDir};
	# run a set of picard tools to get an idea of the quality of datadf
	
	my $cmd6=
	"java -XX:-UseLoopPredicate -client $javaMemory -jar ". $self->binary()."/MarkDuplicates.jar ".
	"VERBOSITY=WARNING ".
	"MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=512 ".
	"INPUT=$bamfile ".
	"O=/dev/null ".
	"VALIDATION_STRINGENCY=SILENT".
	$tempDir." ".
	"M=". $self->outputFile()." ".
	"AS=true";
	

	$self->{logger}->info("Running $cmd6");
	CommonFunc::runCmd($cmd6)if(!defined($self->{reuse} ) );  # mark duplicates
		
}

sub runPicardQCEstimateLibraryComplexity{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx50g';
	my $tempDir=' TMP_DIR='.  $self->{tempDir} ;
	# run a set of picard tools to get an idea of the quality of datadf

	my $cmd5=
	"java -XX:-UseLoopPredicate -client $javaMemory -jar ". $self->binary()."/EstimateLibraryComplexity.jar ".
	"VERBOSITY=WARNING ".
	"INPUT=$bamfile ".
	$tempDir." ".
	"O=".$self->outputFile()." ".
	"VALIDATION_STRINGENCY=SILENT ";
	
	if($self->{mateReads} eq 'true'){
		$self->{logger}->info("Running $cmd5");
		CommonFunc::runCmd($cmd5)if(!defined($self->{reuse} ) ); #library complexity
	}


}
sub runPicardQCCollectWgsMetrics{
	# dummy function
	# we are not using this script to run the picard tools
	
	
}
sub runPicardQCCalculateHSMetrics{
	my($self, $bamfile)=@_;
	my($filename, $directories, $suffix) = fileparse($bamfile);
	my $javaMemory='-Xmx4g';
	my $tempDir=' TMP_DIR='.  $self->{tempDir} ;
	# run a set of picard tools to get an idea of the quality of datadf

	my $cmd5=
	"java -client $javaMemory -jar ". $self->binary()."/CalculateHsMetrics.jar ".
	"VERBOSITY=WARNING ".
	"INPUT=". $bamfile ." ".
	$tempDir." ".
	"BI=". $self->baitsFile()." " .
	"TI=". $self->baitsFile()." " .
	"N=".$self->captureKit()." " .
	"METRIC_ACCUMULATION_LEVEL=ALL_READS ".
	"REFERENCE_SEQUENCE=" . $self->genomeFile() ." ".
	"PER_TARGET_COVERAGE=" . $self->outputFile2("trgcov ")." ".
	"O=".$self->outputFile()." ".
	"VALIDATION_STRINGENCY=SILENT ";
	
	if($self->{mateReads} eq 'true'){
		$self->{logger}->info("Running $cmd5");
		CommonFunc::runCmd($cmd5)if(!defined($self->{reuse} ) ); #library complexity
	}


}
sub captureKit{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting captureKit to $value");
		$self->{captureKit}=$value;
	}
	return $self->{captureKit};
}
sub baitsFile{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting baits file to $value");
		if(!-e $value){ $self->{logger}->logdie("Cannot find file $value")  };
		$self->{baitsfile}=$value;
	}
	return $self->{baitsfile};
}

sub ribosomalintervals{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting ribosomal intervals to $value");
		if(!-e $value){ $self->{logger}->logdie("Cannot find file $value")  };
		$self->{ribosomalintervals}=$value;}

	return $self->{ribosomalintervals};
}

sub refflat{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{logger}->debug("Setting refflat to $value");
		if(!-e $value){ $self->{logger}->logdie("Cannot find file $value")  };
		$self->{refflat}=$value;
	}
	return $self->{refflat};
}


sub parseFile{
	my($self, $bamfile,$step)=@_;

	
	my($filename, $directories, $suffix) = fileparse($bamfile);
	$self->{filename}=File::Spec->rel2abs($bamfile);
	# we need to parse the results from different tools

    $self->{logger}->info("Parsing ". $self->outputFile() );
	if(lc($step) eq 'markduplicates'){	$self->parseDuplicates($self->outputFile() ); } 
	elsif(lc($step) eq 'librarycomplexity'){	$self->parseLibraryComplexity($self->outputFile() ); } 
	elsif(lc($step) eq 'librarycomplexitynorna'){	$self->parseLibraryComplexity($self->outputFile(),'estimated_library_complexity_norna' ); } 
	elsif(lc($step) eq 'collectrnaseqmetrics'){ $self->parseRnaSeqMetrics( $self->outputFile() );}
	elsif(lc($step) eq 'collectinsertsize'){ $self->parseInsertSize( $self->outputFile() );}
	elsif(lc($step) eq 'collectalnsummary'){ $self->parseAlnSummary( $self->outputFile() );}
	elsif(lc($step) eq 'bamindex'){ $self->parseBamIndex( $self->outputFile() );}
	elsif(lc($step) eq 'capturehsmetrics'){ $self->parseHsMetrics( $self->outputFile() );}
	elsif(lc($step) eq 'collectwgsmetrics'){ $self->parseWgsMetrics($self->outputFile());}
	elsif(lc($step) eq 'xenograft'){ $self->parseXenograft( $self->outputFile() );}
	elsif(lc($step) eq 'homer'){ ;}
	else{ $self->{logger}->warn("Unknown QC module $step for picard"); return ; }
}



sub parseXenograft{
	my($self,$file)=@_;
	$self->{logger}->debug("parseXenograft:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	while(my $l=<$rfh>){
		
		chomp $l;
		my($type,$reads)=split(/\t/, $l);
		if($type eq 'HOST_READS'){ $self->{xenograft_host_reads}= $reads;}
		if($type eq 'TUMOUR_READS'){ $self->{xenograft_graft_reads}= $reads;}
		if($type eq 'AMBIGUOUS_READS'){ $self->{xenograft_grafthost_reads}= $reads;}
	}
	close($rfh);

}


sub parseBamIndex{
	my($self,$file)=@_;
	$self->{logger}->debug("parseBamIndex:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	$self->{chromosomename}=[];
	$self->{aligned}=[]; 
	while(my $l=<$rfh>){
		if($l=~/^Java HotSpot(TM)/){ next ;}
		if($l=~/^It's highly recommended /){next ;}
		if($l !~/length=/ and $l !~/Aligned=/){next;}
		if($l=~/NoCoordinateCount=\s+(\d+)/){ 
			push @{ $self->{chromosomename}}, 'unmapped'  ;
			push @{ $self->{aligned}}, $1;
			next;
		}
		my($chr,$l1,$length,$l2,$aligned)=split(/\s+/, $l);
		push @{ $self->{chromosomename}}, $chr;
		push @{ $self->{aligned}}, $aligned;
	}
	close($rfh);
	$self->{logger}->trace("parseBamIndex file $file");
	$self->{logger}->trace("chromosome names: ". join(",", @{ $self->{chromosomename} } ));
	$self->{logger}->trace("aligned bases   : ". join(",", @{ $self->{aligned}}));
}
sub parseWgsMetrics{
	my($self,$file)=@_;
	$self->{logger}->debug("parseWgsMetrics:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	
	
	while(my $l=<$rfh>){
		chomp $l;
		if($l=~/## METRICS CLASS/){
			my $l2=<$rfh>; # read the next line with the labels
			$l2=<$rfh>; # read the line with the values
			chomp $l2;
			(
				$self->{wgs_genome_territory}, 
				$self->{wgs_mean_coverage},
				$self->{wgs_sd_coverage },
				$self->{wgs_median_coverage },
				$self->{ wgs_mad_coverage},
				$self->{ wgs_pct_exc_mapq},
				$self->{wgs_pct_exc_dupe },
				$self->{wgs_pct_exc_unpaired },
				$self->{wgs_pct_exc_baseq },
				$self->{wgs_pct_exc_overlap },
				$self->{ wgs_pct_exc_capped},
				$self->{ wgs_pct_exc_total},
				$self->{wgs_pct_5X },
				$self->{wgs_pct_10X },
				$self->{wgs_pct_15X },
				$self->{ wgs_pct_20X},
				$self->{wgs_pct_25X },
				$self->{wgs_pct_30X },
				$self->{wgs_pct_40X },
				$self->{wgs_pct_50X },
				$self->{ wgs_pct_60X},
				$self->{wgs_pct_70X },
				$self->{ wgs_pct_80X},
				$self->{wgs_pct_90X },
				$self->{ wgs_pct_100X}			
					)=split("\t",$l2); 
		}
		if($l=~/## HISTOGRAM/){
			my $l3=<$rfh>;
			my $arrayIndex=0;
			while($l3=<$rfh>){
				chomp $l3;
				if($l3 eq ""){ next; }
				
				my($abundance,$coverage)=split("\t",$l3);
				$self->{wgs_coverage_abundance}->[$arrayIndex]=$abundance;
				$self->{wgs_coverage}->[$arrayIndex]=$coverage;
				$arrayIndex++;
				
				
			}
		
		}
	}
	

}
sub parseAlnSummary{
	my($self,$file)=@_;
	$self->{logger}->debug("parseAlnSummary:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	
	
	while(my $l=<$rfh>){
		chomp $l;
		if($l=~/METRICS CLASS/){
			$l=<$rfh>;
			my $counter=0;
			while(my $l2=<$rfh>){
				chomp $l2;
				next if $l2 eq "";
				(my $type,
					$self->{total_reads}->[$counter],
					$self->{pf_reads}->[$counter],my $pct1,
					$self->{pf_noise_reads}->[$counter],
					$self->{pf_reads_aligned}->[$counter],my $pct2,
					my $j2,
					$self->{pf_hq_aligned_reads}->[$counter],
					$self->{pf_hq_aligned_bases}->[$counter],
					$self->{pf_hq_aligned_q20_bases}->[$counter],
					$self->{pf_hq_median_mismatches}->[$counter],my $mismatch_rate,my $error_rate, my $indel_rate, 
					$self->{mean_read_length}->[$counter],
					$self->{reads_aligned_in_pairs}->[$counter],my $pct3,
					$self->{bad_cycles}->[$counter]
				)=split("\t", $l2);
				$self->{mean_read_length}->[$counter]=
					int($self->{mean_read_length}->[$counter]);
				$counter ++;
			}
		}
	}
	

	$self->{logger}->trace("parseAlnSummary file $file");
	$self->{logger}->trace(
					"total_reads:",join(",",@{ $self->{total_reads} }), "  ",
					"pf_reads:",join(",",@{ $self->{pf_reads} }), "  ",
					"pf_noise_reads:",join(",",@{ $self->{pf_noise_reads} }), "  ",
					"pf_reads_aligned:",join(",",@{ $self->{pf_reads_aligned} }), "  ",
					"pf_hq_aligned_reads:",join(",",@{ $self->{pf_hq_aligned_reads} }), "  ",
					"pf_hq_aligned_base:s",join(",",@{ $self->{pf_hq_aligned_bases} }), "  ",
					"pf_hq_aligned_q20_bases:",join(",",@{ $self->{pf_hq_aligned_q20_bases} }), "  ",
					"pf_hq_median_mismatches:",join(",",@{ $self->{pf_hq_median_mismatches} }), "  ",
					"mean_read_length:",join(",",@{ $self->{mean_read_length} }), "  ",
					"reads_aligned_in_pairs:",join(",",@{ $self->{reads_aligned_in_pairs} }), "  ",
					"bad_cycles:",join(",",@{ $self->{bad_cycles} }, "  ")
				);
	
}

sub parseDuplicates{
	my($self,$file)=@_;
	$self->{logger}->debug("parseDuplicates:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	while(my $l=<$rfh>){
		if($l=~/# METRICS CLASS/){
			$l=<$rfh>;
			
			$self->{unpaired_reads_examined}=0;
			$self->{read_pairs_examined}=0;
			$self->{umapped_reads}=0;
			$self->{unpaired_read_duplicates}=0;
			$self->{read_pair_duplicates}=0;
			$self->{read_pair_optical_duplicates}=0;
			while(my $l2=<$rfh>){
				chomp $l2;
				if($l2 eq ""){last;}
				$self->{logger}->debug("Parsing line:\n\t$l2");
				my 
				(
					$library,
					$unpaired_reads_examined,
					$read_pairs_examined,
					$umapped_reads,
					$unpaired_read_duplicates,
					$read_pair_duplicates,
					$read_pair_optical_duplicates
				)=split("\t", $l2);
				$self->{unpaired_reads_examined}+=$unpaired_reads_examined;
				$self->{read_pairs_examined}+=$read_pairs_examined;
				$self->{umapped_reads}+=$umapped_reads;
				$self->{unpaired_read_duplicates}+=$unpaired_read_duplicates;
				$self->{read_pair_duplicates}+=$read_pair_duplicates;
				$self->{read_pair_optical_duplicates}+=$read_pair_optical_duplicates;
				$self->{logger}->debug("Found Library:$library\n\tUnpaired Reads: $unpaired_reads_examined");
				
			}
			last;
			
		}
	}
	close($rfh);
}


#parseHsMetrics parses the output from CollectHsMetrics which is something like the following: 
## htsjdk.samtools.metrics.StringHeader

## htsjdk.samtools.metrics.StringHeader
# Started on: Fri Sep 18 22:29:14 UTC 2015

## METRICS CLASS        picard.analysis.directed.HsMetrics
#BAIT_SET        GENOME_SIZE     BAIT_TERRITORY  TARGET_TERRITORY        BAIT_DESIGN_EFFICIENCY  TOTAL_READS     PF_READS        PF_UNIQUE_READS PCT_PF_READS    PCT_PF_UQ_READS PF_UQ_READS_ALIGNED  PCT_PF_UQ_READS_ALIGNED  PF_UQ_BASES_ALIGNED     ON_BAIT_BASES   NEAR_BAIT_BASES OFF_BAIT_BASES  ON_TARGET_BASES PCT_SELECTED_BASES      PCT_OFF_BAIT    ON_BAIT_VS_SELECTED     MEAN_BAIT_COVERAGE   MEAN_TARGET_COVERAGE     PCT_USABLE_BASES_ON_BAIT        PCT_USABLE_BASES_ON_TARGET      FOLD_ENRICHMENT ZERO_CVG_TARGETS_PCT    FOLD_80_BASE_PENALTY    PCT_TARGET_BASES_2X     PCT_TARGET_BASES_10X PCT_TARGET_BASES_20X     PCT_TARGET_BASES_30X    PCT_TARGET_BASES_40X    PCT_TARGET_BASES_50X    PCT_TARGET_BASES_100X   HS_LIBRARY_SIZE HS_PENALTY_10X  HS_PENALTY_20X  HS_PENALTY_30X  HS_PENALTY_40X       HS_PENALTY_50X  HS_PENALTY_100X AT_DROPOUT      GC_DROPOUT      SAMPLE  LIBRARY READ_GROUP
#SureSelect_Human_All_exon_v4+UTRs_71Mb_(Agilent)        3101804739      70569107        70569107        1       121405760       121405760       121405760       1       1       120399290       0.9917	1       12048524628     9210365960      1229964140      1608194528      9210365960      0.866524        0.133476        0.882191        130.515552      130.64193       0.754368        0.754368     33.600276        0.001475        2.666162        0.996598        0.982369        0.950548        0.906663        0.854411        0.797282        0.514687                0       0       0       0    00       1.807404        0.879221

sub parseHsMetrics{
	my($self,$file)=@_;
	$self->{logger}->debug("parseHsMetrics:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	while(my $l=<$rfh>){
		if($l=~/# METRICS CLASS/){
			$l=<$rfh>;
			$l=<$rfh>;
			(
			$self->{bait_set},        
			$self->{genome_size},
			$self->{bait_territory},  
			$self->{target_territory},        
			$self->{bait_design_efficiency},  
			$self->{total_reads     },
			$self->{pf_reads        },
			$self->{pf_unique_reads },
			$self->{pct_pf_reads    },
			$self->{pct_pf_uq_reads },
			$self->{pf_uq_reads_aligned},        
			$self->{pct_pf_uq_reads_aligned}, 
			$self->{pf_uq_bases_aligned     },
			$self->{on_bait_bases   },
			$self->{near_bait_bases },
			$self->{off_bait_bases  },
			$self->{on_target_bases },
			$self->{pct_selected_bases},      
			$self->{pct_off_bait    },
			$self->{on_bait_vs_selected},
	       $self->{ mean_bait_coverage   },   
	       $self->{ mean_target_coverage   }, 
	        $self->{pct_usable_bases_on_bait },       
	        $self->{pct_usable_bases_on_target },     
	        $self->{fold_enrichment },
	        $self->{zero_cvg_targets_pct},    
	        $self->{fold_80_base_penalty  },  
	        $self->{pct_target_bases_2x     },   
	        $self->{pct_target_bases_10x    },
	        $self->{pct_target_bases_20x    },
	        $self->{pct_target_bases_30x    },
	        $self->{pct_target_bases_40x    },
	        $self->{pct_target_bases_50x    },
	        $self->{pct_target_bases_100x   },
	        $self->{hs_library_size },
	        $self->{hs_penalty_10x    }, 
	        $self->{hs_penalty_20x  },
	        $self->{hs_penalty_30x  },
	        $self->{hs_penalty_40x  },
	        $self->{hs_penalty_50x  },
	        $self->{hs_penalty_100x },
	        $self->{at_dropout      },
	        $self->{gc_dropout      },
	        $self->{sample  },
	        $self->{library },
	        $self->{read_group}
			)=split("\t", $l);
			if(!defined($self->{hs_library_size} ) or $self->{hs_library_size} eq ""){$self->{hs_library_size}=0;}
		}
	}
	close($rfh);
}
sub parseLibraryComplexity{
	my($self,$file,$field)=@_;
	if(!defined($field)){$field='estimated_library_size';}
	$self->{logger}->debug("parseLibraryComplexity:Processing file $file for general information");
	$self->{estimated_library_size}=0;
	if($self->mateReads() eq 'false'){return}
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	$self->{estimated_library_size}=0;
	while(my $l=<$rfh>){
		if($l=~/# METRICS CLASS/){
			$l=<$rfh>; # read the line with the titles
			while(my $l2=<$rfh>){
			
				chomp $l2;
				$self->{logger}->debug("parseLibraryComplexity: got line [$l2]");
				if($l2 eq ""){last;}
				my @d=split("\t", $l2);
				
				$self->{$field}+=$d[8];
			}
			last;
		}
	}
	close($rfh);
}


sub parseRnaSeqMetrics{
	my($self,$file)=@_;
	$self->{logger}->debug("parseRnaSeqMetrics:Processing file $file for general information");
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);	
	while(my $l=<$rfh>){
		chomp $l;
		if($l=~/METRICS CLASS/){
			$l=<$rfh>;
			$l=<$rfh>;
			($self->{pf_bases}, 
			$self->{pf_aligned_bases},
			$self->{ribosomal_bases},
			$self->{coding_bases},
			$self->{utr_bases},
			$self->{intronic_bases},
			$self->{intergenic_bases},
			$self->{ignored_reads},
			$self->{correct_strand_reads},
			$self->{incorrect_strand_reads},
			my $pct1,my $pct2,my $pct3,my $pct4,my $pct5,my $pct6,my $pct7,my $pct8,
			$self->{median_cv_coverage},
			$self->{median_5prime_bias},
			$self->{median_3prime_bias})
			=split("\t", $l);

		}
		if($l=~/HISTOGRAM/){
			$l=<$rfh>;

			$self->{norm_coverage}=[0];
			while(my $l2=<$rfh>){
				chomp $l2;
				next if $l2 eq"";
				my($pos,$cov)=split("\t", $l2);
				$self->{norm_coverage}->[$pos]=$cov;
			}
		}
	}
	close($rfh);
	$self->{logger}->trace("parseRnaSeqMetrics file $file");
	$self->{logger}->trace(
			"pf_bases:",$self->{pf_bases}, "  ", 
			"ribosomal_bases:",$self->{ribosomal_bases}, "  ", 
			"ribosomal_bases:",$self->{coding_bases}, "  ", 
			"utr_bases:",$self->{utr_bases}, "  ", 
			"intronic_bases:",$self->{intronic_bases}, "  ", 
			"intergenic_bases:",$self->{intergenic_bases}, "  ", 
			"ignored_reads:",$self->{ignored_reads}, "  ", 
			"correct_strand_reads:",$self->{correct_strand_reads}, "  ", 
			"incorrect_strand_reads:",$self->{incorrect_strand_reads}, "  ", 
			"median_cv_coverage:",$self->{median_cv_coverage}, "  ", 
			"median_5prime_bias:",$self->{median_5prime_bias}, "  ", 
			"median_3prime_bias:",$self->{median_3prime_bias}, "  " 
	);
	$self->{logger}->trace("normalized coverage   : ". join(",", @{ $self->{norm_coverage}}));
}

sub parseInsertSize{
	my($self,$file)=@_;
	$self->{logger}->debug("parseInsertSize:Processing file $file for general information");
	
	
	$self->{insertsize}=[0];
	$self->{insertsizecount}=[0];
	$self->{median_insert_size}=0;
	$self->{median_dev_insert_size}=0;
	$self->{min_insert_size}=0;
	$self->{max_insert_size}=0;
	$self->{mean_insert_size}=0;
	$self->{sdev_insert_size}=0;
	if($self->{mateReads}  ne 'true'){return;}
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($file);
	while(my $l=<$rfh>){
		chomp $l;
		$self->{logger}->trace("Parsing line $l");
		
		if($l=~/# METRICS CLASS/){
			$l=<$rfh>;
			$l=<$rfh>;
			my($median,$median_dev,$min,$max,$mean,$standard_dev)=split("\t",$l);
			$self->{median_insert_size}=int($median);
			$self->{median_dev_insert_size}=int($median_dev);
			$self->{min_insert_size}=int($min);
			$self->{max_insert_size}=int($max);
			$self->{mean_insert_size}=int($mean);
			$self->{sdev_insert_size}=int($standard_dev);

			
		}
		
		
		if($l=~/# HISTOGRAM/){
			$l=<$rfh>;
			$self->{logger}->trace("Initializing extraction of insert size information");
			while(my $l2=<$rfh>){
				chomp $l2;
				next if $l2 eq "";
				
				my ($insertSize, $readCount)=split("\t", $l2);
				push @{$self->{insertsize}}, $insertSize;
				push @{$self->{insertsizecount}}, $readCount;
			}
		}
		
	}
	close($rfh);
	$self->{logger}->trace("parseInsertSize file $file");
	$self->{logger}->trace("insert size       : ". join(",", @{ $self->{insertsize} } ));
	$self->{logger}->trace("insert size count : ". join(",", @{ $self->{insertsizecount}}));
}

sub createDictionary{
	my($self, $bamfile)=@_;
	
	# get the headers of the bamfile
	my $cmd="samtools view -H $bamfile";
	$self->{logger}->trace("Getting headers from $bamfile ($cmd)");
	my @headers=`$cmd`;
	
	# load the existing file
	my $data={};
	my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($self->ribosomalintervals());
	while(my $l=<$rfh>){
		chomp $l;
		$self->{logger}->trace("Processing line $l from ", $self->ribosomalintervals());
		if($l=~/^\@SQ/){
			$l=~/SN:(\S+)/;
			my $name=$1;
			$data->{$name}=[];
		}else{
			my($name)=split("\t", $l);
			push @{$data->{$name}}, $l;
		}
	}
	close($rfh);
	
	# now recreate the dictionary file using the order in the headers
	my($filename, $directories, $suffix) = fileparse($self->ribosomalintervals());
	my $newDictfile="$filename.$$.dict";
	my $wfh=Celgene::Utils::FileFunc::newWriteFileHandle( $newDictfile );
	foreach my $h(@headers){
		chomp $h;
		print $wfh $h."\n";
	}
	foreach my $h(@headers){
		if($h=~/SN:(\S+)/ ){
			my $name=$1;
			my $array_ref=$data->{$name};
			foreach my $d( @$array_ref){
				print $wfh $d."\n";
			}
		}
	}
	close($wfh);
	$self->{logger}->debug("The new dictionary file is stored in $newDictfile");
	$self->ribosomalintervals( $newDictfile );
	if($self->{makeDictAndExit} eq "yes"){
		print "Dictionary found in $newDictfile\n";
		exit(0);
	}
}

1;
