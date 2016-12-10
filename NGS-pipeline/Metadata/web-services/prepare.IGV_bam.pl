#!/usr/bin/env perl
use strict;
use warnings;
use DatabaseFunc;
use File::Spec;


my( $experimentName)=@ARGV;

if(!defined($experimentName)){
	die "Usage <experiment Name> > <experiment.xml>";
}

my $htdoc="/home/kmavromm/html/igv";
my $sql=qq{
	select sa.filename,si.display_name, sa.analysis_task_id
	from sample_info si
	join sample_alignmentqc sa on si.sample_id=sa.sample_id
	where si.experiment = '$experimentName'
	order by si.display_name
};
my $dbh=DatabaseFunc::connectDB();
my $cur=$dbh->prepare($sql);
$cur->execute();
my @data;
while(my ($fullFn, $display,$analysis)=$cur->fetchrow_array()){
	my ($vol,$dir,$fn)=File::Spec->splitpath($fullFn);
	push @data,[ "$display ($analysis)", $fullFn,$fn];
}
$cur->finish();
$dbh->disconnect();

`mkdir -p $htdoc/$experimentName`;

print 
qq{<?xml version="1.0" encoding="UTF-8"?>
<Global name="$experimentName"  infolink="http://www.broadinstitute.org/igv/" version="1">
	<Category name="Bam files">
};
foreach my $d(@data){
	if(!-e $d->[1]){next;}
	`ln -s $d->[1] $htdoc/$experimentName/$d->[2]`;
	`ln -s $d->[1].bai $htdoc/$experimentName/$d->[2].bai`;
	print 
	qq{		<Resource name="$d->[0]"
		path="http://172.16.52.159/igv/$experimentName/$d->[2]" />
	};
	
}
print 
qq{
	</Category>
</Global>
};

