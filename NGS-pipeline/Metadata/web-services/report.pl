#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;
use Log::Log4perl;
use sampleInfo;
use metadataInfo;
use Data::Dumper;;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::Format::HTTP;

#package to provide report information for projects

print "Report \n";
# provide the project name
# a. find the samples of this project


my($projectname)=("H929.2");
print "Project $projectname\n";
my $sample_id_list=
	sampleInfo::getSampleListByProjectName( $projectname );
#print Dumper( $sample_id_list );

foreach my $s( @$sample_id_list ){
print "Sample $s\n";
	my $report=metadataInfo::getStartEndBySampleID( $s );
	# report has: sample, start,end, generator_string, analysis_task
	foreach my $r(@$report){
		if(!defined($r->[1])){next;}
		my $dateparser = DateTime::Format::Strptime->new( pattern => '%a%t%b%t%d%t%H:%M:%S%t%Y' );
		my $startDate = $dateparser->parse_datetime($r->[ 1 ]);
		my $endDate=$dateparser->parse_datetime($r->[ 2 ]);
		my $analysisTask=$r->[4]; if(!defined($analysisTask)){$analysisTask="-1";}
		my $string=$r->[3];
		print $s."\t". $analysisTask."\t".$startDate ."\t". $endDate ."\t";
		my $duration=$endDate->subtract_datetime($startDate);
#		print DateTime::Format::HTTP->format_datetime($duration);
		print sprintf("%.2dm %.2dw %.2dd %.2d:%.2d:%.2d",
		 $duration->months(),$duration->weeks(),$duration->days(),$duration->hours(),
		 	  $duration->minutes(),$duration->seconds() ) ."\t";
		print $string ."\n";
	}
	exit(0);
}
