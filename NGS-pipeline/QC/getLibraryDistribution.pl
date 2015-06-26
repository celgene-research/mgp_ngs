#!/usr/bin/env perl
use strict;
use warnings;
use Celgene::Utils::FileFunc;

#short utility that goes over the fastq file
#and counts how many reads are assigned to each lane
# at the end produces a report which indicates then 
# total number of reads examined
# number of reads that belong to each lane
# this utility is meant to be used within the NGS-QC package

my($inFastq, $outReport)=@ARGV;
if(!defined($inFastq)){
	die"Usage: $0 <input fastq file> <output file [default stdout]\n";
}

if($inFastq eq '--version'){
	print "version 1.0a\n";
	exit(0);
}

if(!defined($outReport)){$outReport="-";}
my $totalReads=0;

my $flowcells={};
my ($instrument ,$flowcell, $lane,$index)=(undef, undef,undef,undef);
my $rfh=Celgene::Utils::FileFunc::newReadFileHandle($inFastq);
while(my $l=<$rfh>){
	chomp $l;
	if($l=~/^@(.+)/){
		my $readName=$1;
		for(my $j=1; $j<=3;$j++){my $junk=<$rfh>;}
		if($readName =~/#/ or $readName !~/\s/){ 
			# this is the old format
			($instrument ,$flowcell,$lane,$index)=_parseOldFormat($readName);
		}else{
			# this is the new format
			($instrument ,$flowcell,$lane,$index)=_parseNewFormat($readName);
		}
		if(!defined( $flowcells->{ $flowcell } )){
			$flowcells->{$flowcell}->{lanes}={};
		}
		if(!defined($flowcells->{$flowcell}->{lanes}->{$lane}) ){
			$flowcells->{$flowcell}->{lanes}->{$lane}=0;
		}
		$flowcells->{  $flowcell  }->{ lanes }->{$lane} ++;
		$flowcells->{ $flowcell  }->{instrument}= $instrument;
		$totalReads ++;
		if($totalReads % 100000 ==0){ print STDERR "$totalReads                    \r";}
	}
}
print STDERR "\n";
close($rfh);

my $wfh=Celgene::Utils::FileFunc::newWriteFileHandle( $outReport);
#produce the report
print $wfh "FILENAME\t".$inFastq."\n";
print $wfh "TOTAL_READS\t".$totalReads."\n";
foreach my $l( keys %$flowcells){
	foreach my $lane ( keys %{ $flowcells->{$l}->{lanes} } ){
		if(!defined( $flowcells->{$l}->{lanes}->{$lane})){next;}
		print $wfh "LANE\t".$flowcells->{$l}->{instrument}.":". $l.":". $lane ."\t";
		print $wfh "READS\t". $flowcells->{$l}->{lanes}->{$lane} ."\t";	
		print $wfh "\n";
	}
}
close($wfh);


#	HWUSI-EAS100R	the unique instrument name
#	6	flowcell lane
#	73	tile number within the flowcell lane
#	941	'x'-coordinate of the cluster within the tile
#	1973	'y'-coordinate of the cluster within the tile
#	#0	index number for a multiplexed sample (0 for no indexing)
#	/1	the member of a pair, /1 or /2 (paired-end or mate-pair reads only)
sub _parseOldFormat{
	my($l)=@_;
	my @d=split(":",$l);
	my ($instrument,$flowcell,$lane)=($d[0],$d[0],$d[1]);
	
	$l=~/\#([ATGC\.N]+)\/*/; 
	my $index=$1;if(!defined($index)){$index=0;}
	return($instrument,$flowcell,$lane,$index);
}
#	@EAS139:136:FC706VJ:2:2104:15343:197393 1:Y:18:ATCACG
#	EAS139	the unique instrument name
#	136	the run id
#	FC706VJ	the flowcell id
#	2	flowcell lane
#	2104	tile number within the flowcell lane
#	15343	'x'-coordinate of the cluster within the tile
#	197393	'y'-coordinate of the cluster within the tile
#	1	the member of a pair, 1 or 2 (paired-end or mate-pair reads only)
#	Y	Y if the read fails filter (read is bad), N otherwise
#	18	0 when none of the control bits are on, otherwise it is an even number
#	ATCACG	index sequence
sub _parseNewFormat{
	my($l)=@_;
	my ($a,$b)=split(" ", $l);
	my @d=split(":",$a);
	my($instrument,$flowcell,$lane)=($d[0], $d[2], $d[3]);
	my @e=split(":",$b);
	my($index)=($e[3]);
	return($instrument,$flowcell, $lane, $index);
}