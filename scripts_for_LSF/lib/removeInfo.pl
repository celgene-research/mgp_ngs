#!/usr/bin/env perl

while(my $l = <> ){
	if($l =~ /^#/) { print $l ; next }	
	my @d=split("\t", $l);
	print join( "\t",@d[0..5] );
	print "\t\t";
	print join( "\t",@d[-2..-1] );
}
