#!/usr/bin/perl -w

use strict;
use Frontier::Client;
use Data::Dumper;

my $server_url = 'http://localhost:8082/RPC2';

my $server = Frontier::Client->new('url' => $server_url);
my @samples=('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24');

my $result = $server->call('sampleInfo.getOmicSoftTable', 
@samples);


my $biorepCounter={};
my $techrepCounter={};
foreach my $row( @$result){
	$row->[24].=".". ++$biorepCounter->{ $row->[24] } ;
	$row->[25].=".". ++$techrepCounter->{ $row->[25] } ;
	
	print join("\t", @$row)."\n";
}
