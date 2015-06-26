#!/usr/bin/env perl

use strict;
use warnings;
use Celgene::Utils::FileFunc;
use Getopt::Long;
# use this script to convert a single read fastq file 
# to two fastq files of paired reads.
# each read will get a suffix /1 or /2
# the paired end read will have the same length as the original one 
# with its sequence set to Ns and the quality Bs
# if the outputs are existing files the script will append the reads to the
# existing files
my $version="0.1a";
my($inputFile, $output1, $output2,$versionout,$help);

GetOptions(
	"input=s"=>\$inputFile, 
	"output1=s"=>\$output1,
	"output2=s"=>\$output2,
	"version!"=>\$versionout,
	"help"=>\$help
);

if(defined($help)){ printUsage();exit(0);}

if(defined($versionout)){print "makePairedReads.pl $version\n";exit(0);}
if(!defined($inputFile) or !defined($output1) or !defined($output2)){
	print "Please provide the necessary arguments\n";
	printUsage();
	exit(1);
}
sub printUsage{
	print 
	"makePairedReads.pl  $version\n".
	"arguments:\n".
	" --input <single fastq file to process> \n".
	" --output1 <output file for first mate read> \n".
	" --output2 <output file for second mate read> \n".
	" --version get the version of this script\n";
	
}



my $inFh=Celgene::Utils::FileFunc::newReadFileHandle( $inputFile );
my ($outFh1,$outFh2);
if( -e $output1 ){ $outFh1 = Celgene::Utils::FileFunc::newAppendFileHandle( $output1 );}
else{ $outFh1= Celgene::Utils::FileFunc::newWriteFileHandle( $output1);}
if( -e $output2 ){ $outFh2 = Celgene::Utils::FileFunc::newAppendFileHandle( $output2 );}
else{ $outFh2= Celgene::Utils::FileFunc::newWriteFileHandle( $output2);}



my $seqName="";
while(my $seqName=<$inFh>){
	chomp $seqName;
	my $sequence= <$inFh>; chomp $sequence;
	my $qualityName = <$inFh>;chomp $qualityName;
	my $quality=<$inFh>;chomp $quality;
	$seqName =~/(\S+)/;
	$seqName =~s%/1%%;
	$seqName =~s%/2%%;
	
	
	if(length($sequence) != length($quality)){
		die "Different lengths of sequence and quality strings :\n".
		$seqName . "\n".
		$sequence ."\n".
		$quality ."\n";
	}
	print $outFh1
		$seqName ."/1" ."\n".
		$sequence ."\n".
		'+' ."\n".
		$quality ."\n";
		
	print $outFh2
		$seqName ."/2" ."\n".
		'N'x length($sequence) ."\n".
		'+' . "\n".
		'B'x length($quality) ."\n";
		
	
}
close( $inFh);
close( $outFh1); close ($outFh2);