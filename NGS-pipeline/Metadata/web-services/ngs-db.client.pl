#!/usr/bin/perl -w

use strict;
use Frontier::Client;
use Data::Dumper;

my $server_url = 'http://10.130.5.63:8084/RPC2';
$ENV{ SOLR_PORT }=8084;
print "Accessing server $server_url\n";

my $server = Frontier::Client->new('url' => $server_url);
#my @samples=('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24');
#
#my $result = $server->call('sampleInfo.getOmicSoftTable', 
#@samples);

#my $result=$server->call("metadataInfo.getDerivedFromByFilename", 
#"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/cufflinks/Cg-5_coord/chr12.cufflinks/transcripts.gtf");
#my $result=$server->call("metadataInfo.getDerivedFromByFilename", 
#"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/bamfiles/STAR.human-4cufflinks/sortedBAM/Cg-1_coord.bam");
#print Dumper( $result );
#my @sids=();
#foreach my $f(@$result){
#	my $sid=$server->call("metadataInfo.getSampleIDByFilename",
#	$f);
#	@sids=(@sids,@$sid);
#}
#print join(":", @sids), "\n";


#my $result=$server->call("metadataInfo.getSampleIDByDerivedFrom", 
#"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/cufflinks/Cg-5_coord/chr12.cufflinks/transcripts.gtf"
#);


#my $result=$server->call("metadataInfo.getSampleIDByFilename",
#"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/variants/highQualityCalls/genelist/chr10_.list");
my $result=$server->call("metadataInfo.getSOLRIDByFilename",
"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/variants/highQualityCalls/genelist/chr10_.list" );
print Dumper($result);

print "processing $result->[0]\n";
$server->call("metadataInfo.updateFieldBySOLRID",
"FilePath",
"/opt/Medussa2/Projects/Analysis/Discovery/LNCaP/RNAseq/experiment1/analysis/kmavromm/variants/highQualityCalls/genelist-test2/chr10_.list" ,
$result->[0]);