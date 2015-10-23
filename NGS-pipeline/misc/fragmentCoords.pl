#!/usr/bin/env perl


use strict;
use warnings;

my ($splitNumber)=@ARGV;

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
		print "$k:" . 1 . "-" . $chromSize{$k} . "\n";
	}else{
		my $i;
		for($i=$chunkSize; $i < $chromSize{ $k } ; $i+= $chunkSize){
			print "$k:" . ($i - $chunkSize + 1) . "-" . $i . "\n";
			
		}
		if($i> $chromSize{$k} ){
			print "$k:" . ($i - $chunkSize + 1) . "-" . $chromSize{$k} . "\n";
		}
	}
}
