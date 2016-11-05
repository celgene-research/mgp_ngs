#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl;
use FindBin;
use Getopt::Long;
use lib $FindBin::RealBin;
use lib $FindBin::RealBin."/lib/";
#use DatabaseFunc;
use File::Spec;
use File::Basename;
use picardQCsteps;
use homerQCsteps;
use Celgene::Utils::SVNversion;
use Celgene::Utils::ArrayFunc;
use Celgene::Metadata::FileConversion;
use Frontier::Client;
use Sys::Hostname;
use Data::Dumper;
my $host=hostname;
my $arguments=join(" ",@ARGV);
#my $annotationFile="/opt/reference/Homo_sapiens/GENCODE/hg19/Annotation/gencode.v14.refFlat"; # for ENSEMBL

my ($logLevel,$logFile,$manifest,$help,$inputFQ,$inputBAM,$samplename,$nocommit,$reuse, $nofilecheck, $mapper,$baitsFile,$captureKit)=('INFO',undef,undef);
my($ribosomal_intervals,$annotationFile,$strand,$genomeFile,$outputFile,$programVersion,$usersample_id,$genomeVersion,$sampleFlag,$compatibility);
my $qcStep;
GetOptions(
	"loglevel=s"=>\$logLevel,
	"logfile=s"=>\$logFile,
	"qcfile=s"=>\$outputFile,
	"qcStep=s"=>\$qcStep,
	"inputbam=s"=>\$inputBAM,
	"reuse"=>\$reuse,
	"outputfile=s"=>\$compatibility,
	"nocommit"=>\$nocommit,
	"sample_flag=s"=>\$sampleFlag,
	"nofilecheck"=>\$nofilecheck,
	"version"=>\$programVersion,
	"sample_id=i"=>\$usersample_id,
	"baitsFile=s"=>$baitsFile,
	"captureKit=s"=>\$captureKit,
	"help"=>\$help
);


#outputfile is an option that is not use any more, but kept for compatibility
if(defined($compatibility)) { $outputFile=$compatibility;}


if(defined($help)){
	printHelp();
	exit 0;
}

if(!defined($logFile)){
	if(defined($samplename)){$logFile= $samplename.".log";}
	else{$logFile = "runQC.log";}
}
my $version=Celgene::Utils::SVNversion::version( '$Date: 2015-10-14 09:31:15 -0700 (Wed, 14 Oct 2015) $ $Revision: 1709 $' );
sub printHelp{
	print
	"$0. $version program that drives the QC analysis of samples\n".
	"arguments\n".
	" --qcfile <file with stored QC output>. The contents of this file will be automatically added to the database\n".
	" --sample_id : the sample id of the dataset. (in case of tools that need normal/tumor pairs it corresponds to the 'tumor' pair\n".
	" --sample_flag a flag the defines the type of sample information to store 
	('original' : for the standard information [default]
	 'tumor'/'host'  : for Qc on processed xenograft data, used to store either host or tumor data)\n".
	" --qcStep define QC module to run 
	('MarkDuplicates','CollectAlnSummary','BamIndex','LibraryComplexity',
	'CollectInsertSize' : used only for paired end sequences,
	'CollectWgsMetrics' : used only for Whole Genome Sequencing projects,
	'CollectRNASeqMetrics': used only for RNA Sequencing projects,
	'CaptureHsMetrics': used only for Whole Exome Sequencing projects,
	'Xenograft': used only for Xenograft models,
	'Homer': used only for ChIP Sequencing projects,
	'Sequenza': used for WES and WGS datasets)\n".
	" --nocommit will not update the database\n".
	" --nofilecheck will not check if input files (bam) exists.\n".
	" --version will return the version(s) of the QC programs\n".
	" --logLevel/--logFile standard logger arguments\n".
	" --help this screen\n".
	"\n\n";
}


my $port=8082;
if(defined($ENV{NGS_SERVER_PORT})){ 
	$port= $ENV{NGS_SERVER_PORT};
}
my $ip="localhost";
if(defined($ENV{NGS_SERVER_IP})){ 
	$ip= $ENV{NGS_SERVER_IP};
}
my $server_url = "http://".$ip.":".$port."/RPC2";
my $server = Frontier::Client->new('url' => $server_url);


# this script is used to initiate the local QC process on a set 
# of fastq and bam files that correspond to ONE sample only


my $logConf=qq{
	log4perl.rootLogger          = $logLevel, Logfile, Screen
    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = $logFile
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%p : %c - %d] - %m{chomp}%n
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = [%p - %d] - %m{chomp}%n
};
Log::Log4perl->init(\$logConf);
my $logger=Log::Log4perl->get_logger("runQC-bam");




my $picardQC=picardQCsteps->new();
my $homerQC=homerQCsteps->new();
my $QCversion=$picardQC->getVersion();
my $QChomerversion=$homerQC->getVersion();
if(defined($programVersion)){ print $QCversion," ",$QChomerversion,"\n"; exit(0);}

if(!defined($outputFile)){
	printHelp();
	$logger->logdie("Please provide the name of the qcstats file (qcfile)");
		
}
if( !defined($sampleFlag)){ $sampleFlag='original'}


$logger->info("$0 ($version).");
$logger->info("Host: $host");
$logger->info("Arguments $arguments");
$logger->info("Processing qc  files $outputFile");


my ($sample_id, $is_stranded, $is_paired_end);
if(!defined($usersample_id)){
	($sample_id, $is_stranded, $is_paired_end)=getsampleid( $outputFile,$sampleFlag );
	if( (!defined($sample_id) or $sample_id eq 'NA') and defined($inputBAM)){
		($sample_id, $is_stranded, $is_paired_end)=getsampleid( $inputBAM,$sampleFlag );	
	}
	if($sample_id eq 'NA'){ $logger->logdie("Neither a sample id was provided nor was it possible to get from the name of the qc file ($outputFile)");}
}else{
	$sample_id=$usersample_id;
}

#############################################
# run the steps

my $bamfile='null'; 
$picardQC->outputFile($outputFile );
$picardQC->mateReads( $is_paired_end );
$picardQC->strandness( $is_stranded);
$picardQC->reuse();
$picardQC->runPicardQC($bamfile,$qcStep);
$picardQC->parseFile( $bamfile, $qcStep);


$homerQC->outputDirectory($outputFile );
$homerQC->reuse();
$homerQC->runHomerQC($bamfile,$qcStep);
$homerQC->parseFile( $bamfile, $qcStep);


if(lc($qcStep) eq 'homer'){	
	my $bq=processBAMhomer( $homerQC );
#	print Dumper( $bq );
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id,$sampleFlag);
}

if($qcStep eq 'CaptureHsMetrics'){	
#	if((!defined($reuse) and !defined($baitsFile)) or !defined($captureKit)){ $logger->logdie("In order to run CaptureHsMetrics you need to provide captureKit and baitsFile")};
	my $bq=processBAMCalculateHsMetrics( $picardQC );
#	print Dumper( $bq );
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'MarkDuplicates'){	
	my $bq=processBAMMarkDuplicates( $picardQC );
#	print Dumper( $bq );
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'CollectAlnSummary'){
	my $bq=processBAMCollectAlnSummaryMetrics( $picardQC );
#	print Dumper( $bq );
#	exit;
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'CollectInsertSize'){
	my $bq=processBAMCollectInsertSizeMetrics( $picardQC );
#	print Dumper( $bq );
#	exit;
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag );
}
if($qcStep eq 'CollectRNASeqMetrics'){
	my $bq=processBAMCollectRNASeqMetrics( $picardQC );
#print Dumper( $bq );
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag );
}
if($qcStep eq 'CollectWgsMetrics'){
	my $bq=processBAMCollectWgsMetrics( $picardQC );
#print Dumper( $bq );
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag );
}
if($qcStep eq 'BamIndex'){
	my $bq=processBAMBamIndex( $picardQC );
#	print Dumper( $bq );
#	exit;

	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'LibraryComplexity'){
	my $bq=processBAMLibraryComplexity( $picardQC );
#	print Dumper( $bq );
#	exit;
	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'Xenograft'){
	my $bq=processXenograft( $picardQC );
#	print Dumper( $bq );
#	exit;

	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}
if($qcStep eq 'Sequenza'){
	my $bq=processSequenza( $picardQC );
	$logger->debug( Dumper( $bq ) );
#	exit;

	getFromXMLserver('sampleQC.updateAlignmentQC',$bq, $sample_id, $sampleFlag);
}


$logger->info("Processing finished successfully");



sub getsampleid{
	my ($bamfile,$flag)=@_;
	if(defined($usersample_id)){return ($usersample_id,undef,undef);}
	my($is_paired_end,$is_stranded)=(undef,undef);
	my ($sql,$cur,$sample_id);
	# get the sample id from the  metadata
	# for this to work we need to make sure that each file has only one sample_id
	my @irodsSampleID;my @t1;my @t2;

	my @bam=split(",",$bamfile);
	foreach my $bam(@bam){
		
		$bam=File::Spec->rel2abs( $bam ) if ($bam !~/^s3/);
		my $t=getFromXMLserver('metadataInfo.getSampleIDByFilename',$bam);
		@t2=(@t2, @$t);
	}
	@irodsSampleID=(@t1,@t2);
	@irodsSampleID=Celgene::Utils::ArrayFunc::unique( \@irodsSampleID );
	if(scalar(@irodsSampleID) >1){
		$logger->logdie("Cannot assign file $bamfile to multiple samples (got ",join(",",@irodsSampleID),")");
	}elsif (scalar(@irodsSampleID)==0){
		return undef;
	}else{
		$sample_id= $irodsSampleID[0];
		$logger->debug("From file metadata the sample was found to be $sample_id");
		
	}
	
	$logger->info("Retrieving information for sample $sample_id");
	# check if the sample exists in sample_sequencing

	my $result1=getFromXMLserver('sampleInfo.getSampleBamQCByID', $sample_id,$flag);
	my $result2=getFromXMLserver('sampleInfo.getSampleExperimentByID', $sample_id);
	
	#print Dumper( $result1 );
	#print Dumper( $result2 );
	if(!defined($result1) or $result1 eq ""){
		$logger->info("Inserting entry for $sample_id in table sample_alignmentqc");
		my %h=('sample_id'=>$sample_id);
		getFromXMLserver('sampleInfo.createSampleBamQC', \%h, $flag);
	}else{
		$logger->info("Entry for $sample_id in table sample_alignmentqc already exists");
		my($check_id,$mr,$sr)=($result1->{sample_id}, $result2->{paired_end},$result2->{stranded});
		$is_paired_end=$mr;
		$is_stranded=$sr;
	}
#	$dbh->disconnect();
	if(defined($is_paired_end) and ($is_paired_end eq '0' or $is_paired_end eq 'no')){$is_paired_end='false';}
	if(defined($is_paired_end) and ($is_paired_end eq '1' or $is_paired_end eq 'yes')){$is_paired_end='true';}

	if(!defined($is_stranded)){$is_stranded='NONE';}
	if(!defined($is_paired_end)){$is_paired_end='undef';}
	$logger->info("Is paired end: $is_paired_end");
	$logger->info("Is stranded: $is_stranded");
	return ($sample_id, $is_stranded, $is_paired_end);
}

sub processBAMCalculateHsMetrics{
	my($picardQC)=@_;
	return { 
			'genome_size'=> $picardQC->{genome_size},
			'bait_territory'=>=> $picardQC->{bait_territory},  
			'target_territory'=>=> $picardQC->{target_territory},        
			'bait_design_efficiency'=>=> $picardQC->{bait_design_efficiency},  
			'on_bait_bases'=> $picardQC->{on_bait_bases   },
			'near_bait_bases'=> $picardQC->{near_bait_bases },
			'off_bait_bases'=> $picardQC->{off_bait_bases  },
			'on_target_bases'=> $picardQC->{on_target_bases },
			'pct_selected_bases'=> $picardQC->{pct_selected_bases},      
			'pct_off_bait'=> $picardQC->{pct_off_bait    },
			'on_bait_vs_selected'=> $picardQC->{on_bait_vs_selected},
	        'mean_bait_coverage'=> $picardQC->{ mean_bait_coverage   },   
	        'mean_target_coverage'=> $picardQC->{ mean_target_coverage   }, 
	        'pct_usable_bases_on_bait'=> $picardQC->{pct_usable_bases_on_bait },       
	        'pct_usable_bases_on_target'=> $picardQC->{pct_usable_bases_on_target },     
	        'fold_enrichment'=> $picardQC->{fold_enrichment },
	        'zero_cvg_targets_pct'=> $picardQC->{zero_cvg_targets_pct},    
	        'fold_80_base_penalty'=> $picardQC->{fold_80_base_penalty  },  
	        'pct_target_bases_2x'=> $picardQC->{pct_target_bases_2x     },   
	        'pct_target_bases_10x'=> $picardQC->{pct_target_bases_10x    },
	        'pct_target_bases_20x'=> $picardQC->{pct_target_bases_20x    },
	        'pct_target_bases_30x'=> $picardQC->{pct_target_bases_30x    },
	        'pct_target_bases_40x'=> $picardQC->{pct_target_bases_40x    },
	        'pct_target_bases_50x'=> $picardQC->{pct_target_bases_50x    },
	        'pct_target_bases_100x'=> $picardQC->{pct_target_bases_100x   },
	        'hs_library_size'=> $picardQC->{hs_library_size },
	        'hs_penalty_10x'=> $picardQC->{hs_penalty_10x    }, 
	        'hs_penalty_20x'=> $picardQC->{hs_penalty_20x  },
	        'hs_penalty_30x'=> $picardQC->{hs_penalty_30x  },
	        'hs_penalty_40x'=> $picardQC->{hs_penalty_40x  },
	        'hs_penalty_50x'=> $picardQC->{hs_penalty_50x  },
	        'hs_penalty_100x'=> $picardQC->{hs_penalty_100x },
	        'at_dropout'=> $picardQC->{at_dropout      },
	        'gc_dropout'=> $picardQC->{gc_dropout      }
	};
}

sub processBAMMarkDuplicates{
	my($picardQC)=@_;
#	print Dumper($picardQC);

	return {
		'unpaired_read_duplicates' => $picardQC->{unpaired_read_duplicates},
		'read_pairs_examined' =>  $picardQC->{read_pairs_examined},
		'read_pair_duplicates' =>  $picardQC->{read_pair_duplicates},
		'unpaired_reads_examined' =>  $picardQC->{unpaired_reads_examined},
		'umapped_reads' =>  $picardQC->{umapped_reads},
		'read_pair_optical_duplicates' =>  $picardQC->{read_pair_optical_duplicates},
		'mdup_library_size'=>$picardQC->{mdup_library_size}
	};
	
}
sub processBAMCollectInsertSizeMetrics{
		my($picardQC)=@_;
	return {
		'insertsize' => $picardQC->{insertsize},
		'mean_insert_size' => $picardQC->{mean_insert_size},
		'min_insert_size' => $picardQC->{min_insert_size},
		'sdev_insert_size' => $picardQC->{sdev_insert_size},
		'max_insert_size' => $picardQC->{max_insert_size},
		'median_insert_size' => $picardQC->{median_insert_size},
		'median_dev_insert_size' => $picardQC->{median_dev_insert_size},
		'insertsizecount' => $picardQC->{insertsizecount}
	};
	
}
sub processBAMCollectRNASeqMetrics{
	my($picardQC)=@_;
	
	return {
		'pf_bases' => $picardQC->{pf_bases}, 
		'pf_aligned_bases' => $picardQC->{pf_aligned_bases},
		'ribosomal_bases' => $picardQC->{ribosomal_bases},
		'coding_bases' => $picardQC->{coding_bases},
		'utr_bases' => $picardQC->{utr_bases},
		'intronic_bases' => $picardQC->{intronic_bases},
		'intergenic_bases' => $picardQC->{intergenic_bases},
		'ignored_reads' => $picardQC->{ignored_reads},
		'correct_strand_reads' => $picardQC->{correct_strand_reads},
		'incorrect_strand_reads' => $picardQC->{incorrect_strand_reads},
		'median_cv_coverage' => $picardQC->{median_cv_coverage},
		'median_5prime_bias' => $picardQC->{median_5prime_bias},
		'median_3prime_bias' => $picardQC->{median_3prime_bias},
		'norm_coverage' => $picardQC->{norm_coverage}
	};
	
}

sub processBAMCollectWgsMetrics{
	my($picardQC)=@_;
	# fields from qcstatss file to store are:
	#GENOME_TERRITORY        MEAN_COVERAGE   SD_COVERAGE     MEDIAN_COVERAGE 
	#MAD_COVERAGE  PCT_EXC_MAPQ    PCT_EXC_DUPE    PCT_EXC_UNPAIRED        
	#PCT_EXC_BASEQPCT_EXC_OVERLAP  PCT_EXC_CAPPED  PCT_EXC_TOTAL   
	#PCT_5X  PCT_10X PCT_15X PCT_20X       PCT_25X PCT_30X PCT_40X PCT_50X PCT_60X PCT_70X PCT_80X PCT_90X PCT_100X
	
	return {
		'wgs_genome_territory' => $picardQC->{wgs_genome_territory}, 
		'wgs_mean_coverage' => $picardQC->{wgs_mean_coverage},
		'wgs_sd_coverage' => $picardQC->{wgs_sd_coverage },
		'wgs_median_coverage' => $picardQC->{wgs_median_coverage },
		'wgs_mad_coverage' => $picardQC->{ wgs_mad_coverage},
		'wgs_pct_exc_mapq' => $picardQC->{ wgs_pct_exc_mapq},
		'wgs_pct_exc_dupe' => $picardQC->{wgs_pct_exc_dupe },
		'wgs_pct_exc_unpaired' => $picardQC->{wgs_pct_exc_unpaired },
		'wgs_pct_exc_baseq' => $picardQC->{wgs_pct_exc_baseq },
		'wgs_pct_exc_overlap' => $picardQC->{wgs_pct_exc_overlap },
		'wgs_pct_exc_capped' => $picardQC->{ wgs_pct_exc_capped},
		'wgs_pct_exc_total' => $picardQC->{ wgs_pct_exc_total},
		'wgs_pct_5X' => $picardQC->{wgs_pct_5X },
		'wgs_pct_10X' => $picardQC->{wgs_pct_10X },
		'wgs_pct_15X' => $picardQC->{wgs_pct_15X },
		'wgs_pct_20X' => $picardQC->{ wgs_pct_20X},
		'wgs_pct_25X' => $picardQC->{wgs_pct_25X },
		'wgs_pct_30X' => $picardQC->{wgs_pct_30X },
		'wgs_pct_40X' => $picardQC->{wgs_pct_40X },
		'wgs_pct_50X' => $picardQC->{wgs_pct_50X },
		'wgs_pct_60X' => $picardQC->{ wgs_pct_60X},
		'wgs_pct_70X' => $picardQC->{wgs_pct_70X },
		'wgs_pct_80X' => $picardQC->{ wgs_pct_80X},
		'wgs_pct_90X' => $picardQC->{wgs_pct_90X },
		'wgs_pct_100X' => $picardQC->{ wgs_pct_100X},
		'wgs_coverage_abundance'=>$picardQC->{wgs_coverage_abundance},
		'wgs_coverage' => $picardQC->{wgs_coverage }
		
		
		
		
		
		
	};
	
}


sub processBAMCollectAlnSummaryMetrics{
	my($picardQC)=@_;
	return {
		'pf_hq_aligned_reads' => $picardQC->{pf_hq_aligned_reads},
		'pf_hq_median_mismatches' => $picardQC->{pf_hq_median_mismatches},
		'pf_noise_reads' => $picardQC->{pf_noise_reads},
		'mean_read_length' => $picardQC->{mean_read_length},
		'pf_reads_aligned' => $picardQC->{pf_reads_aligned},
		'bad_cycles' => $picardQC->{bad_cycles},
		'total_reads' => $picardQC->{total_reads},
		'pf_hq_aligned_bases' => $picardQC->{pf_hq_aligned_bases},
		'pf_hq_aligned_q20_bases' => $picardQC->{pf_hq_aligned_q20_bases},
		'reads_aligned_in_pairs' => $picardQC->{reads_aligned_in_pairs},
		'pf_reads' => $picardQC->{pf_reads}
	};
	
}
sub processBAMBamIndex{
	my($picardQC)=@_;


	return {
		'strandness'=>$picardQC->{strandness},
		'aligned'=>$picardQC->{aligned},
		'chromosomename'=>$picardQC->{chromosomename}	
	};	
}


sub processXenograft{
	my($picardQC)=@_;


	return {
		'xenograft_host_reads'=>$picardQC->{xenograft_host_reads},
		'xenograft_graft_reads'=>$picardQC->{xenograft_graft_reads},
		'xenograft_grafthost_reads'=>$picardQC->{xenograft_grafthost_reads}	
	};	
}

sub processSequenza{
	my($picardQC)=@_;


	return {
		'sequenza_cellularity'=>$picardQC->{sequenza_cellularity},
		'sequenza_ploidy'=>$picardQC->{sequenza_ploidy},
		'sequenza_slpp'=>$picardQC->{sequenza_slpp}	
	};	
}

sub processBAMLibraryComplexity{
	my($picardQC)=@_;
	return {
		'estimated_library_size' => $picardQC->{estimated_library_size}
	}
}

sub processBAMhomer{
	my($homerQC)=@_;
	print Dumper($homerQC);	
	return{
		'homer_taggccontent'=> $homerQC->{ tag_gc},
		'homer_taggccount'=> $homerQC->{ tag_gc_total},
		'homer_genomegccontent'=> $homerQC->{genome_gc},
		'homer_genomegccount'=> $homerQC->{genome_gc_total},
		'homer_fragment_length'=> $homerQC->{fragment_length_estimate},
		'homer_peak_width'=> $homerQC->{peak_width_estimate},
		'homer_tagdistance'=> $homerQC->{distance},
		'homer_tagautocorrelation_samestrand'=> $homerQC->{same_strand_count},
		'homer_tagautocorrelation_oppositestrand'=> $homerQC->{opposite_strand_count},
		'homer_tags_position'=> $homerQC->{tags_position},
		'homer_tags_per_position'=> $homerQC->{tags_per_position},
	};
	
}

# finding the library of the reads is equivalent to
#samtools view $1 | cut -f3,4 -d ':'| uniq | sort | uniq | tr ':' '      '

# run a set of picard tools to get an idea of the quality of data
#java -jar /Volumes/work/kmavromatis/picard-tools-1.81/CollectInsertSizeMetrics.jar 
#	I=/Volumes/work/kmavromatis/QC.CLL/bamfiles/US-1424436.fixed.bam 
#	H=InsertSize/US-1424436.fixed.pdf 
#	LEVEL=ALL_READS 
#	O=US-1424436.fixed.insertsize 
#	VALIDATION_STRINGENCY=SILENT & 

#java -Xmx10g -jar /Volumes/work/kmavromatis/picard-tools-1.81/CollectRnaSeqMetrics.jar 
#	REF_FLAT=//Volumes/work/kmavromatis/reference/annotation/gencode.v14.refFlat 
#	RIBOSOMAL_INTERVALS=/Volumes/work/kmavromatis/reference/annotation/gencode.v14.rRNA 
#	CHART=CollectRnaSeqMetrics/US-1424436.fixed.pdf 
#	LEVEL=ALL_READS 
#	I=/Volumes/work/kmavromatis/QC.CLL/bamfiles/US-1424436.fixed.bam  
#	O=CollectRnaSeqMetrics/US-1424436.fixed.collectRnaSeqMetrics 
#	STRAND=NONE 
#	VALIDATION_STRINGENCY=SILENT

#java -jar /Volumes/work/kmavromatis/picard-tools-1.81/CollectAlignmentSummaryMetrics.jar 
#	I=/Volumes/work/kmavromatis/QC.CLL/bamfiles/US-1424436.fixed.bam 
#	O=CollectAlignmentMetrics/US-1424436.fixed.alnmetrics 
#	VALIDATION_STRINGENCY=SILENT & 

#java -jar /Volumes/work/kmavromatis/picard-tools-1.81/BamIndexStats.jar 
#	I=/Volumes/work/kmavromatis/QC.CLL/bamfiles/US-1424436.fixed.bam 
#	VALIDATION_STRINGENCY=SILENT > BamIndexStats/US-1424436.fixed.bamIndexStats &


sub getFromXMLserver{
	my(@args)=@_;
	my $retArray;
	my $result;
	my $retries = 10;
	if(defined($nocommit)){
		$logger->info("getFromXMLserver: nothing will be commited to the database.");
		return;
	}
	for(my $r=1; $r<= $retries; $r++){
		$retArray=eval{$server->call( @args ); } ;
		
		if($@){
			$logger->warn("getFromXMLserver: Attempt $r to connect server failed with error [$@]");
			
			if( $r==$retries){
				$logger->logdie("getFromXMLserver: Cannot contact server. Aborting !!!")
			}
			
		}else{
			if($r>1){
                $logger->info("getFromXMLserver: Attempt $r/$retries was successful");
            }else{
            	$logger->info("getFromXMLserver: Data retrieval from server was successful");
            }
            
            last;
			
		}
	}
	#while( 1 ){
	#	$result = $server->call( @args );
		
	#	$logger->warn("Got bad response from server [$result]. Retrying in 2 seconds");
	#	sleep(2);
	#}
	return $retArray;
}
