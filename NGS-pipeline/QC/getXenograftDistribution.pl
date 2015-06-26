#!/usr/bin/env perl
use strict;
use warnings;


my ($inputFn,$outputFn)=@ARGV;
if($inputFn eq '--version'){ printVersion(); exit 0;}
if($inputFn eq '--help'){printUsage(); exit 0;}

sub printVersion{ print "getXenograftDistribution.pl v 0.1a\n";}
sub printUsage{
	printVersion();
	print"usage getXenograftDistribution.pl <input bam> <output txt>\n";
}


my $host=0;
my $tumour=0;
my $both=0;
my $unmapped=0;
open(my $rfh, "samtools view $inputFn| ") or die "Cannot start samtools to view file $inputFn\n";
while(my $line=<$rfh>){
	chomp $line;
	my($read, $flag,$chrom)=split("\t", $line);
	if($line =~/	XX:A:b/){ $both ++; }
	if($chrom ne '*'){
		if($line =~/	XX:A:h/){ $host ++; }
	}else{
		$unmapped ++;
	}
	if($line =~/	XX:A:t/){ $tumour ++; }
	
}
close($rfh);


open (my $wfh , ">$outputFn") or die "Cannot create file $outputFn\n";
print $wfh 
	"FILE\t$inputFn\n".
	"HOST_READS\t$host\n".
	"TUMOUR_READS\t$tumour\n".
	"AMBIGUOUS_READS\t$both\n".
	"UNMAPPED_READS\t$unmapped\n";
close $wfh;