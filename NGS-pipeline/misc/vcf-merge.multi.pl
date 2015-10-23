#!/usr/bin/env perl
use strict;
use warnings;
use Celgene::Utils::FileFunc;
use Cwd;
use File::Basename;
# this is a wrapper around vcf-merge but it does a lot of splitting of files etc

# the only input is the step followed by thelist of vcf files to merge
# step = 1 means split hte files and do hte merging 
#
#
# it first splits the list of files in groups of 200 which can be merged
# each merge happens in regions 
# at the end all regions have to be concatenated
# and all the merges be remerged
my $step=shift @ARGV;
my @listOfFiles=@ARGV;


 
if($step ==1 ){

my($start,$end);
# split the list of files into smaller more manageable lists of up to 200 files
for(my $i=0 ; $i< scalar(@listOfFiles); $i+=200){
	$start=$i;
	$end=$i+200-1;
	if($end >= scalar(@listOfFiles)){ $end = scalar(@listOfFiles)  -1 ; } 
	my @lf=@listOfFiles[ $start .. $end ];
	#print " Chunk $start .. $end of ".scalar(@listOfFiles)."\n";
	
	vcfmerge(\@lf,$start,$end);
	
}
}

if($step ==2){
my @array;
# merge together the files that come from the same region but from diferent list of files
foreach my $f( @listOfFiles){
	my $bname=basename($f); $bname=~s/.vcf.gz//;
 	my($start,$end,$chr,$coordstart,$coordend)=split("-", $bname );
	push @array, [ $start,$end,$chr,$coordstart,$coordend,$f ];
}
@array=sort{    $a->[ 2 ] cmp  $b->[ 2 ] ||
		$a->[ 3 ] <=> $b->[ 3 ] ||
		$a->[ 0 ] <=> $b->[ 0] } @array;

my @lf=();
for(my $r=0; $r<scalar(@array);$r++){
	my $rec=$array[ $r ];
	my $previousRec=$array[ $r -1 ];
	if( ($r == (scalar(@array)-1)) or ($r >0  and ( $rec->[ 2 ] ne $previousRec->[2] or $rec->[3] ne $previousRec->[3] )) ){
		vcfmerge( \@lf, 0,'N', "$previousRec->[2]:$previousRec->[3]-$previousRec->[4]");
		@lf=();
	}
	push @lf, $rec->[5] ;
}


}

if($step ==3){
# just concatenate the files
#
my @array;
`zgrep '^#' $listOfFiles[1] | grep -v cgpAnalysisProc> final.vcf`;
foreach my $f( @listOfFiles){
        my $bname=basename($f); $bname=~s/.vcf.gz//;
        my($start,$end,$chr,$coordstart,$coordend)=split("-", $bname );
        push @array, [ $chr,$coordstart,$coordend,$f ];
}

@array=sort{  
                $a->[ 1 ] <=> $b->[ 1 ] } @array;
my @chromosomes=( "chrM","chr1","chr2","chr3","chr4","chr5","chr6","chr7","chr8","chr9","chr10","chr11","chr12","chr13","chr14","chr15","chr16","chr17","chr18","chr19","chr20","chr21","chr22","chrX","chrY");
foreach my $chr(  @chromosomes){
	foreach my $a(@array){
		if($a->[0] eq $chr){
			print "Adding $a->[3]\n";
			`zcat $a->[3] | grep -v '^#'  | awk '{print \"chr\"\$0}' >> final.vcf`;
		}

	}	


}


}

# run vcf-merge

sub vcfmerge{
	my($listOfFiles,$start,$end,$useFragments)=@_;
	my $fragments =[];
	if(!defined($useFragments) ){$fragments= fragmentCoordinates(100);}
	else{ push @$fragments, $useFragments ;}	
	`mkdir step-${step}/bsub -p`;


	foreach my $f(@$fragments){
		my $outputfname=$f; $outputfname=~s/:/-/;
#		$f=~s/chr//;
		$outputfname="$start-$end-$outputfname";
		my $cmd=
"cd ".getcwd().";
mkdir step-${step}/merge -p;
mkdir step-${step}/logs -p;

vcf-merge -r $f ".join(" ",@$listOfFiles)." > step-${step}/merge/$outputfname.vcf  ;  
bgzip step-${step}/merge/$outputfname.vcf ; 
tabix -p vcf step-${step}/merge/$outputfname.vcf.gz";
		my $wfh=Celgene::Utils::FileFunc::newWriteFileHandle( "step-${step}/bsub/$outputfname.bsub");
		print $wfh "#BSUB -o step-${step}/logs/$outputfname.stdout\n#BSUB -e step-1/logs/$outputfname.stderr \n".$cmd."\n";
		close $wfh;
		system("bsub < step-${step}/bsub/$outputfname.bsub");
	}
	
}



sub fragmentCoordinates{
	my ($splitNumber)=@_;
	
	# tool to generate a list of coordinates in the form 
	# chrN:START-END
	# which can be used to parallelize processes
	
	my %chromSize=(
	'chrM'=>16569,
	'chr1'=>249250621,
	'chr2'=>243199373,
	'chr3'=>198022430,
	'chr4'=>191154276,
	'chr5'=>180915260,
	'chr6'=>171115067,
	'chr7'=>159138663,
	'chr8'=>146364022,
	'chr9'=>141213431,
	'chr10'=>135534747,
	'chr11'=>135006516,
	'chr12'=>133851895,
	'chr13'=>115169878,
	'chr14'=>107349540,
	'chr15'=>102531392,
	'chr16'=>90354753,
	'chr17'=>81195210,
	'chr18'=>78077248,
	'chr19'=>59128983,
	'chr20'=>63025520,
	'chr21'=>48129895,
	'chr22'=>51304566,
	'chrX'=>155270560,
	'chrY'=>59373566
	);
	
	
	my @retArray;
	my $totalSize=0;
	foreach my $k( keys %chromSize){
		$totalSize += $chromSize{ $k };
	}
	#print STDERR "The total genome size is $totalSize\n";
	
	my $chunkSize= int($totalSize/$splitNumber);
	#print STDERR "Each chunk will be approximately $chunkSize bp\n";
	
	my $start=1;
	foreach my $k( sort {$a cmp $b }keys %chromSize){
		if($chunkSize >= $chromSize{$k}){
			
			push @retArray, "$k:" . 1 . "-" . $chromSize{$k} ;
		}else{
			my $i;
			for($i=$chunkSize; $i < $chromSize{ $k } ; $i+= $chunkSize){
				push @retArray, "$k:" . ($i - $chunkSize + 1) . "-" . $i ;
				
			}
			if($i> $chromSize{$k} ){
				push @retArray, "$k:" . ($i - $chunkSize + 1) . "-" . $chromSize{$k} ;
			}
		}
	}
	return(\@retArray);
}
