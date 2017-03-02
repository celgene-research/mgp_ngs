#!/usr/bin/perl
# Standardize translocation calls.
# Usage: curate_joint_TCs.pl
# John Obenauer, 2/17/2017

$tcfile = "2017-01-11_complete_translocation_table_pass3_FINAL.csv";

# Start output file
open(OUT, ">curated_" . $tcfile);
print OUT "ss1\tss2\tCyto_Translocation_CONSENSUS\t" . 
    "CYTO_t(4;14)_WES_MANTA\t" . 
    "CYTO_t(6;14)_WES_MANTA\t" . 
    "CYTO_t(8;14)_WES_MANTA\t" . 
    "CYTO_t(11;14)_WES_MANTA\t" . 
    "CYTO_t(14;16)_WES_MANTA\t" . 
    "CYTO_t(14;20)_WES_MANTA\t" . 

    "CYTO_t(4;14)_WGS_MANTA\t" . 
    "CYTO_t(6;14)_WGS_MANTA\t" . 
    "CYTO_t(8;14)_WGS_MANTA\t" . 
    "CYTO_t(11;14)_WGS_MANTA\t" . 
    "CYTO_t(14;16)_WGS_MANTA\t" . 
    "CYTO_t(14;20)_WGS_MANTA\t" . 

    "CYTO_t(4;14)_RNA_MANTA\t" . 
    "CYTO_t(6;14)_RNA_MANTA\t" . 
    "CYTO_t(8;14)_RNA_MANTA\t" . 
    "CYTO_t(11;14)_RNA_MANTA\t" . 
    "CYTO_t(14;16)_RNA_MANTA\t" . 
    "CYTO_t(14;20)_RNA_MANTA\t" . 
    "UK_Call\tDFCI_FISH\n";


open(TC, $tcfile);
$hdrline = <TC>;
@hdr = split(/\t/, $hdrline);
while (<TC>) {
    chomp;
    @parts = split(/\t/);
    $study = $parts[2]; # Dataset
    $ss1 = $parts[0]; # sample_id
    $ss2 = $parts[3]; # WES_prep_id
    $tc_consensus = $parts[27]; # Translocation_Summary
    print OUT "$ss1\t$ss2\t$tc_consensus";
    
    # WES
    print OUT &select_value($parts[4], "MMSET");
    print OUT &select_value($parts[5], "CCND3");
    print OUT &select_value($parts[6], "MAFA");
    print OUT &select_value($parts[7], "CCND1");
    print OUT &select_value($parts[8], "MAF");
    print OUT &select_value($parts[9], "MAFB");
    
    # WGS
    print OUT &select_value($parts[11], "MMSET");
    print OUT &select_value($parts[12], "CCND3");
    print OUT &select_value($parts[13], "MAFA");
    print OUT &select_value($parts[14], "CCND1");
    print OUT &select_value($parts[15], "MAF");
    print OUT &select_value($parts[16], "MAFB");
    
    # RNA
    print OUT &select_value($parts[18], "MMSET");
    print OUT &select_value($parts[19], "CCND3");
    print OUT &select_value($parts[20], "MAFA");
    print OUT &select_value($parts[21], "CCND1");
    print OUT &select_value($parts[22], "MAF");
    print OUT &select_value($parts[23], "MAFB");
    
    print OUT "\t$parts[25]"; # UK call
    print OUT "\t$parts[26]"; # DFCI FISH
    
    print OUT "\n";
    
}
close(TC);
close(OUT);


sub select_value(my $tc, my $value) {
    my $tc = $_[0];
    my $value = $_[1];
    if ($tc eq $value) {
        return "\t1";
    } elsif ($tc eq "NA") {
        return "\tNA";
    } else {
        return "\t0";
    }
}

