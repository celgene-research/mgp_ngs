#!/usr/bin/env perl
use strict;
use warnings;


# use this script to get the ASCII range for the quality scores from a bam file

# usage 
# samtools view XXX.bam | checkQualityEncoding.pl 

# returns the baseline of quality (33 or 64) 


my $min=100;
my $max =0;
while(my $line = <>){
	chomp $line;
	my @a=split("\t", $line);
	
	my $qual=$a[10];
	my @qualArray=split("", $qual);
	
	foreach my $q( @qualArray ){
		
		my $qualValue=ord( $q );
		if($qualValue < $min ){ $min = $qualValue;}
		if($qualValue > $max ){ $max = $qualValue;}
	}
}


if( $min >=64){
	print "64";
}else{
	print "33";
}