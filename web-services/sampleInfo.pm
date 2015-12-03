package sampleInfo;
use strict;
use warnings;
use Celgene::Utils::DatabaseFunc;
use Data::Dumper;
my $logger=Log::Log4perl->get_logger("sampleInfo");
# contain functions for the NGS API that have to do with the sampleInfo database
# get the full row of the database when a db sample_id is provided

sub getSampleByID{
	my ($sample_id, $dbhParam)=@_;
#	my $sample_id=1;

	
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
		$logger->info("getSampleByID: Connecting to database");
	}else{
		$dbh=$dbhParam;
	}
	
	$logger->info("getSampleByID: Reference info for sample_id is ", ref($sample_id));
	if(ref ($sample_id) =~/ARRAY/){
		my $S=join(qq{','},@$sample_id);
		$sample_id=$S;
	}
	
	my $sql=qq{
		select si.*, se.*, et.*, pr1.experiment_prep_method as library_prep_method, pr2.experiment_prep_method as rna_selection_method, pr3.experiment_prep_method as exome_bait_set_name, vc.vendor as vendor_name
		from sample_info si
		join sample_experiment se on si.sample_id=se.sample_id
		join experiment_type_cv et on et.experiment_type_id=se.experiment_type
		join experiment_prep_method_cv pr1 on pr1.experiment_prep_method_id = se.library_prep
		left join experiment_prep_method_cv pr2 on pr2.experiment_prep_method_id = se.rna_selection
		left join experiment_prep_method_cv pr3 on pr3.experiment_prep_method_id = se.exome_bait_set
		join vendor_cv vc on se.vendor=vc.vendor_id
		where si.sample_id in ('$sample_id')
	};
	$logger->info("getSampleByID: Executing $sql");
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $result=$cur->fetchrow_hashref();
	$cur->finish();
	
	
	return $result;	
}

sub getSampleFastQCByID{
	my ($sample_id, $flag,$dbhParam)=@_;
#	my $sample_id=1;
	if(!defined($flag)){$flag='original';}
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
		$logger->info("getSampleFastQCByID: Connecting to database");
	}else{
		$dbh=$dbhParam;
	}
	
	my $sql=qq{
		select si.*,se.stranded, se.paired_end as mate_reads, tech.technology
		from sample_readqc si
		join sample_experiment se on si.sample_id = se.sample_id
		join technology_cv tech on tech.technology_id= se.technology
		where si.sample_id=$sample_id and si.flag='$flag'};

	
	$logger->info("getSampleFastQCByID: Executing $sql");
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $result=$cur->fetchrow_hashref();
	$cur->finish();
	
	return $result;	
}

sub getSampleExperimentByID{
	my ($sample_id, $dbhParam)=@_;
#       my $sample_id=1;
        my $dbh;
        if(!defined($dbhParam)){
                $dbh=Celgene::Utils::DatabaseFunc::connectDB();
                $logger->info("getSampleExperimentByID: Connecting to database");
        }else{
                $dbh=$dbhParam;
        }

        my $sql=qq{
                select se.*
                from  sample_experiment se
                join technology_cv tech on tech.technology_id= se.technology
                where se.sample_id=$sample_id};


        $logger->info("getSampleExperimentByID: Executing $sql");
        my $cur=$dbh->prepare($sql);
        $cur->execute();
        my $result=$cur->fetchrow_hashref();
        $cur->finish();

        return $result;
}

sub getSampleBamQCByID{
	my ($sample_id,$flag,$dbhParam)=@_;
#	my $sample_id=1;
 	if(!defined($flag)){$flag='original';}
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
		$logger->info("getSampleBamQCByID: Connecting to database");
	}else{
		$dbh=$dbhParam;
	}
	
	my $sql=qq{
		select *
		from sample_alignmentqc si
		where si.sample_id=$sample_id and si.flag='$flag'
		limit 1
	};
	
	$logger->info("getSampleBamQCByID: Executing $sql");
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $result=$cur->fetchrow_hashref();
	$cur->finish();
	if(!defined($result)){ return undef; }	
	# R seems to have problem with very large numbers
	# to avoid this problem we divide all the numbers refering to bases
	# with 1,000,000
	foreach my $k(keys %$result){
		
		if( $k =~/bases/) { $result->{$k}/=1000000 if defined($result->{$k})}
	}
	
	return $result;	
}



sub getSampleByVendorID{
	my($vendor_id,$project_name,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$logger->info("getSampleByVendorID: Connecting to database");
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
		
	}else{
		$dbh=$dbhParam;
	}
	
	my $sql=qq{
		select si.sample_id
		from sample_info si
		join project_info pi on si.project_id=pi.project_id
		where si.vendor_id='$vendor_id'
		and pi.project_name='$project_name'
	};
	$logger->info("getSampleByVendorID: Executing $sql");
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my($sample_id)=$cur->fetchrow_array();
	$cur->finish();
	$logger->info("getSampleByVendorID: Got sample [$sample_id] for vendor id [$vendor_id]");
	my $return=getSampleByID( $sample_id, $dbh );
	return ($return);
	
}

sub createSampleFastQC{
	my($inputHash,$flag,$dbhParam)=@_;
	if(!defined($flag)){$flag='original';}
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	my $sql=qq/
		insert into sample_readqc
		(sample_id, flag) values 
		($inputHash->{sample_id}, '$flag')
		/;	
	$logger->debug("createSampleFastQC:  Runing sql $sql");
	$dbh->do( $sql ) ;
}	

sub createSampleBamQC{
	my($inputHash,$flag,$dbhParam)=@_;
	my $dbh;
	if(!defined($flag)){$flag='original';}
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	my $sql=qq/
		insert into sample_alignmentqc
		(sample_id,flag) values 
		($inputHash->{sample_id}, '$flag')
		/;	
	$logger->debug("createSampleBamQC:  Runing sql $sql");
	$dbh->do( $sql ) ;
}	

sub createSample{
	my($inputHash,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("createSample: Connecting to database");
	my $sql=qq/
		insert into  sample_info 
		(date_added,vendor_id,celgene_id,project_id,
		biological_replicates_group,technical_replicates_group,
		cell_line,
		is_useful,
		display_name,response,cell_type,
		vendor_project_name,
		compound_array,dose_array,time_treatment,xenograft,tissue,condition,
		reference_genome,host_genome,
		response_desc, response_array)
		values
		(current_date,
		'$inputHash->{vendor_id}','$inputHash->{celgene_id}',$inputHash->{project_id},
		$inputHash->{biological_replicates_group},$inputHash->{technical_replicates_group},
		'$inputHash->{cell_line}',
		'yes',
		'$inputHash->{display_name}','$inputHash->{response}','$inputHash->{cell_type}',
		'$inputHash->{vendor_project_name}',
		'{ "/ . join('","', @{$inputHash->{compound_array}}). qq/"}',
		'{ "/ . join('","', @{$inputHash->{dose_array}}).qq/"}',
		$inputHash->{time_treatment},$inputHash->{xenograft},'$inputHash->{tissue}',
		'$inputHash->{condition}',
		'$inputHash->{reference_genome}', '$inputHash->{host_genome}',
		'{ "/ . join('","', @{$inputHash->{response_desc_array}}). qq/"}',
		'{ "/ . join('","', @{$inputHash->{response_array}}). qq/"}'
		)
	/;
	$sql=~s/'NULL'/NULL/g;
	$logger->debug("createSample:  Runing sql $sql");
	$dbh->do( $sql ) ;
	my $sample_id=$dbh->last_insert_id( undef,undef,"sample_info","sample_id");
	
	$sql=qq{
		insert into  sample_experiment 
		( sample_id, technology, experiment_type, vendor, antibody, antibody_target,stranded,paired_end,library_prep,rna_selection,exome_bait_set )
		values
		( $sample_id, $inputHash->{technology}, 
		$inputHash->{experiment_type}, $inputHash->{vendor}, 
		'$inputHash->{antibody}', '$inputHash->{antibody_target}',
		'$inputHash->{stranded}', '$inputHash->{paired_end}',
		$inputHash->{library_prep}, $inputHash->{rna_selection}, $inputHash->{exome_bait_set}) 
	};
	$logger->debug("createSample:  Runing sql $sql");
	$dbh->do( $sql ) ;
	
	foreach my $c(@{$inputHash->{celgene_project_desc_id}} ){
		$sql=qq{
			insert into  sample_celgene_project   
			( sample_id, celgene_project_desc_id)
			values
			( $sample_id, $c)
			
		};
		$dbh->do($sql);
	$logger->debug("createSample:  Running sql $sql");
	}
	
	foreach my $p( @{ $inputHash->{avs}}){
	my $sql=qq{insert into sample_av
			(sample_id, name, value)
			values
			( $sample_id, '$p->[0]','$p->[1]')
		};
		$dbh->do($sql);
	}
	return($sample_id);
}

sub getProjectByName{
	my($project_name,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("getProjectByName: Connecting to database");
	my $sql=qq{
		select pi.project_id
		from project_info pi
		where pi.project_name ='$project_name'	};
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my($project_id)=$cur->fetchrow_array();
	$cur->finish();
	return($project_id);
}

sub getSampleListByProjectName{
	my($project_name,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("getSampleListByProjectName: retrieving project id for project [$project_name]");
	my $project_id=getProjectByName( $project_name ,$dbhParam);
	$logger->info("getSampleListByProjectName: Connecting to database");
	$logger->info("getSampleListByProjectName: Getting samples for project [$project_id]");
	my $sql=qq{
		select si.sample_id 
		from sample_info si
		where si.project_id='$project_id'
		order by si.sample_id asc
	};
	
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $returnArray=[];
	while( my($sample_id)=$cur->fetchrow_array()){
		push @$returnArray, $sample_id;
	}
	$cur->finish();
	
	
	return($returnArray);
}


# create a project when the nmae of a project is given and return the project id of the new project
# if the project name exists the method will return the existing project
sub getOrCreateProjectByName{
	my($project_name,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("getOrCreateProjectByName: Connecting to database");
	# create teh project if it does not exist in the database
	my $project_id=getProjectByName( $project_name,  $dbh);
	if(!defined($project_id)){
		my $cSql=qq{
			insert into project_info(project_name)
			values('$project_name')
		};
		$dbh->do($cSql);
		$project_id = $dbh->last_insert_id(undef, undef, 'project_info', undef);
	}
	return($project_id);
}

# create a project relationship as synonyms between two projects when this
# relationshisp does note exist
sub createProjectSynonyms{
        my($project_id1, $project_id2,$dbhParam)=@_;
        my $dbh;
        if(!defined($dbhParam)){
                $dbh=Celgene::Utils::DatabaseFunc::connectDB();
        }else{
                $dbh=$dbhParam;
        }
        $logger->info("createProjectSynonyms: Connecting to database");
        # create teh project if it does not exist in the database
        my $aSql=qq{ select * from project_relations
		where (project_id=$project_id1 and child_id=$project_id2) or
		      (project_id=$project_id2 and child_id=$project_id1)
	};
	my $cur=$dbh->prepare($aSql);$cur->execute();
	my @arr=$cur->fetchrow_array();
	if(scalar(@arr)>0){
		$logger->info("createProjectSynonyms: there is already a connection between the two projects [$project_id1] and [$project_id2]");
	}
	else{	
		my $cSql=qq{
               	  insert into project_relations(project_id, child_id, child_type)
               	  values($project_id1, $project_id2, 'S')
        	};
        	$dbh->do($cSql);
	}
       	$cur->finish(); 
}


# returns a hash that contains the CV for a given table
# the function returns two hashes one value=>id and one id=>value
# there is always a one to one relationship
sub getTableCV{
	my($table,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("getTableCV: Connecting to database");
	my $hash={};
	my $rhash={};
	my $sql=qq{ select * from $table};
	my $cur=$dbh->prepare($sql);$cur->execute();
	while(my ($id,$value)=$cur->fetchrow_array()){
		$logger->debug("Loading hash by running $sql");
		$hash->{ $value }=$id;
		$rhash->{$id }=$value;
		$logger->debug("Got $id $value");
	}
	return {hash=>$hash,rhash=>$rhash};
}

sub enterCV{
	my($table,$column,$value,$dbhParam)=@_;
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("enterCV: Connecting to database");
	my $sql=qq{ insert into $table ($column) values ('$value')};
	$logger->debug("Inserting new value in the database\n$sql");
	$dbh->do($sql);
	my $choise = $dbh->last_insert_id( undef, undef,$table, undef );
	return ($choise);
}

sub getOmicSoftTable{
	my(@sample_id) = @_;
	my $dbh;
	
	$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	
	my $sampleStr= join(qq{','},@sample_id);
	my $sql=qq{
		select si.tissue as "Tissue",
		si.cell_line as "CellLine",si.cell_type as "CellType",
		si.compound_array[1] as "Compound",si.dose_array[1] as "Dose",
		si.compound_array[2] as "Compound1",si.dose_array[2] as "Dose1",
		si.compound_array[3] as "Compound2",si.dose_array[3] as "Dose2",
		si.compound_array[4] as "Compound3",si.dose_array[4] as "Dose3",
		si.compound_array[5] as "Compound4",si.dose_array[5] as "Dose4",
		si.compound_array[6] as "Compound5",si.dose_array[6] as "Dose5",
		si.compound_array[7] as "Compound6",si.dose_array[7] as "Dose6",
		si.compound_array[8] as "Compound7",si.dose_array[8] as "Dose7",
		si.compound_array[9] as "Compound8",si.dose_array[9] as "Dose8",
		si.time_treatment as "Time",
		si.condition as "Condition",
		si.response as "Response",
		si.biological_replicates_group as "BioRep",
		si.technical_replicates_group as "TechRep",
		se.antibody as "Antibody",
		se.antibody_target as  "AntibodyTarget"
		from sample_info si
		join sample_experiment se on si.sample_id=se.sample_id
		where si.sample_id in ('} . 
		$sampleStr . qq{')
		order by "BioRep", "TechRep"
		};
	$logger->debug("Executing $sql");
	my $cur=$dbh->prepare($sql);$cur->execute();
	my @retValue;
	push @retValue, $cur->{NAME};
	while(my @data=$cur->fetchrow_array()){
		push @retValue, [@data];
	}
	
	$cur->finish();
	
	return \@retValue;
}


sub updateAlignmentQC{
	my($bq, $sample_id, $flag,$dbhParam)=@_;
	if(!defined($flag)){$flag='original';}
	if( ref( $bq )=~/ARRAY/){
		my @tmp=@$bq;
		my %tmp=@tmp;
		$bq= \%tmp;
	}
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("updateReadQC: Connecting to database");
	$logger->trace( Dumper( $bq ) );
	my $sqlh="update sample_alignmentqc set( ";
		$sqlh.= "insert_size," if defined($bq->{insertsize});
		$sqlh.= "insert_abundance,", if defined($bq->{insertsizecount});
		$sqlh.= "median_insert_size," if defined($bq->{median_insert_size});
		$sqlh.=" median_dev_insert_size," if defined($bq->{median_dev_insert_size});
		$sqlh.=" min_insert_size," if defined($bq->{min_insert_size});
		$sqlh.=" max_insert_size," if defined($bq->{max_insert_size});
		$sqlh.=" mean_insert_size," if defined($bq->{mean_insert_size});
		$sqlh.=" sdev_insert_size," if defined($bq->{sdev_insert_size});
		$sqlh.=" chromosome_name, chromosome_aligned," if defined($bq->{chromosomename});
		$sqlh.=" pf_bases," if defined($bq->{pf_bases});
		$sqlh.=" pf_aligned_bases," if defined($bq->{pf_aligned_bases});
		$sqlh.=" ribosomal_bases," if defined($bq->{ribosomal_bases});
		$sqlh.= "coding_bases," if defined($bq->{coding_bases});
		$sqlh.= "utr_bases," if defined($bq->{utr_bases});
		$sqlh.=" intronic_bases," if defined($bq->{intronic_bases});
		$sqlh.=" intergenic_bases," if defined($bq->{intergenic_bases});
		$sqlh.=" ignored_reads," if defined($bq->{ignored_reads});
		$sqlh.= "correct_strand_reads," if defined($bq->{correct_strand_reads});
		$sqlh.= "incorrect_strand_reads," if defined($bq->{incorrect_strand_reads});
		$sqlh.=" median_cv_coverage," if defined($bq->{median_cv_coverage});
		$sqlh.= "median_5prime_bias," if defined($bq->{median_5prime_bias});
		$sqlh.=" median_3prime_bias," if defined($bq->{median_3prime_bias});
		$sqlh.= "norm_coverage," if defined($bq->{norm_coverage});
		$sqlh.= "total_reads," if defined($bq->{total_reads});
		$sqlh.= "pf_reads," if defined($bq->{pf_reads});
		$sqlh.=" pf_noise_reads," if defined($bq->{pf_noise_reads});
		$sqlh.= "pf_reads_aligned," if defined($bq->{pf_reads_aligned});
		$sqlh.=" pf_hq_aligned_reads," if defined($bq->{pf_hq_aligned_reads});
		$sqlh.=" pf_hq_aligned_bases," if defined($bq->{pf_hq_aligned_bases});
		$sqlh.=" pf_hq_aligned_q20_bases," if defined($bq->{pf_hq_aligned_q20_bases});
		$sqlh.=" pf_hq_median_mismatches," if defined($bq->{pf_hq_median_mismatches});
		$sqlh.=" mean_read_length," if defined($bq->{mean_read_length});
		$sqlh.=" reads_aligned_in_pairs," if defined($bq->{reads_aligned_in_pairs});
		$sqlh.=" bad_cycles," if defined($bq->{bad_cycles});
		$sqlh.=" estimated_library_size," if defined($bq->{estimated_library_size});
		$sqlh.=" unpaired_reads_examined," if defined($bq->{unpaired_reads_examined});
		$sqlh.=" read_pairs_examined," if defined($bq->{read_pairs_examined});
		$sqlh.=" umapped_reads," if defined($bq->{umapped_reads});
		$sqlh.=" unpaired_read_duplicates," if defined($bq->{unpaired_read_duplicates});
		$sqlh.=" read_pair_duplicates," if defined($bq->{read_pair_duplicates});
		$sqlh.=" read_pair_optical_duplicates," if defined($bq->{read_pair_optical_duplicates});
		$sqlh.=" filename," if defined($bq->{filename});

	 	$sqlh.="genome_size," if defined($bq->{ genome_size});
 		$sqlh.="bait_territory," if defined($bq->{  bait_territory});
 		$sqlh.="target_territory," if defined($bq->{          target_territory});
 		$sqlh.="bait_design_efficiency," if defined($bq->{       bait_design_efficiency});     
 		$sqlh.="on_bait_bases," if defined($bq->{   on_bait_bases});
 		$sqlh.="near_bait_bases," if defined($bq->{  near_bait_bases});
 		$sqlh.="off_bait_bases," if defined($bq->{  off_bait_bases});
 		$sqlh.="on_target_bases," if defined($bq->{ on_target_bases});
 		$sqlh.="pct_selected_bases," if defined($bq->{      pct_selected_bases});
 		$sqlh.="pct_off_bait," if defined($bq->{    pct_off_bait});
 		$sqlh.="on_bait_vs_selected," if defined($bq->{  on_bait_vs_selected});
 	        $sqlh.="mean_bait_coverage," if defined($bq->{      mean_bait_coverage});
 	        $sqlh.="mean_target_coverage," if defined($bq->{    mean_target_coverage});
 	        $sqlh.="pct_usable_bases_on_bait," if defined($bq->{        pct_usable_bases_on_bait});
 	        $sqlh.="pct_usable_bases_on_target," if defined($bq->{     pct_usable_bases_on_target });
 	        $sqlh.="fold_enrichment," if defined($bq->{ fold_enrichment});
 	        $sqlh.="zero_cvg_targets_pct," if defined($bq->{    zero_cvg_targets_pct});
 	        $sqlh.="fold_80_base_penalty," if defined($bq->{     fold_80_base_penalty});
 	        $sqlh.="pct_target_bases_2x," if defined($bq->{         pct_target_bases_2x});
 	        $sqlh.="pct_target_bases_10x," if defined($bq->{     pct_target_bases_10x});
 	        $sqlh.="pct_target_bases_20x," if defined($bq->{     pct_target_bases_20x});
 	        $sqlh.="pct_target_bases_30x," if defined($bq->{     pct_target_bases_30x});
 	        $sqlh.="pct_target_bases_40x," if defined($bq->{     pct_target_bases_40x});
 	        $sqlh.="pct_target_bases_50x," if defined($bq->{     pct_target_bases_50x});
 	        $sqlh.="pct_target_bases_100x," if defined($bq->{    pct_target_bases_100x});
 	        $sqlh.="hs_library_size," if defined($bq->{ hs_library_size});
 	        $sqlh.="hs_penalty_10x," if defined($bq->{      hs_penalty_10x});
 	        $sqlh.="hs_penalty_20x," if defined($bq->{   hs_penalty_20x});
 	        $sqlh.="hs_penalty_30x," if defined($bq->{   hs_penalty_30x});
 	        $sqlh.="hs_penalty_40x," if defined($bq->{   hs_penalty_40x});
 	        $sqlh.="hs_penalty_50x," if defined($bq->{   hs_penalty_50x});
 	        $sqlh.="hs_penalty_100x," if defined($bq->{  hs_penalty_100x});
 	        $sqlh.="at_dropout," if defined($bq->{       at_dropout});
 	        $sqlh.="gc_dropout," if defined($bq->{gc_dropout});
		
		$sqlh.="xenograft_graft_reads," if defined($bq->{xenograft_graft_reads});
		$sqlh.="xenograft_host_reads," if defined($bq->{xenograft_host_reads});
		$sqlh.="xenograft_grafthost_reads," if defined($bq->{xenograft_grafthost_reads});
	
	
	$sqlh.=" rrnacov_mean," if defined($bq->{rrnacov_mean});
	$sqlh.=" rrnacov_median," if defined($bq->{rrnacov_median});
	$sqlh.=" rrnacov_stdev," if defined($bq->{rrnacov_stdev});
	$sqlh.=" rrnacov_max," if defined($bq->{rrnacov_max});
	$sqlh.=" rrnacov_min," if defined($bq->{rrnacov_min});
	$sqlh.=" rrnacov_pct5," if defined($bq->{rrnacov_pct5});
	$sqlh.=" rrnacov_pct25," if defined($bq->{rrnacov_pct25});
	$sqlh.=" rrnacov_pct50," if defined($bq->{rrnacov_pct50});
	$sqlh.=" rrnacov_pct75," if defined($bq->{rrnacov_pct75});
	$sqlh.=" rrnacov_pct95," if defined($bq->{rrnacov_pct95});

		$sqlh.=" homer_taggccontent," if defined($bq->{homer_taggccontent});
		$sqlh.=" homer_taggccount," if defined($bq->{homer_taggccount});
		$sqlh.=" homer_genomegccontent," if defined($bq->{homer_genomegccontent});
		$sqlh.=" homer_genomegccount," if defined($bq->{homer_genomegccount});
		$sqlh.=" homer_fragment_length," if defined($bq->{homer_fragment_length});
		$sqlh.=" homer_peak_width," if defined($bq->{homer_peak_width});
		$sqlh.=" homer_tagdistance," if defined($bq->{homer_tagdistance});
		$sqlh.=" homer_tagautocorrelation_samestrand," if defined($bq->{homer_tagautocorrelation_samestrand});
		$sqlh.=" homer_tagautocorrelation_oppositestrand," if defined($bq->{homer_tagautocorrelation_oppositestrand});
		$sqlh.=" homer_tags_position," if defined($bq->{homer_tags_position});
		$sqlh.=" homer_tags_per_position," if defined($bq->{homer_tags_per_position});

		$sqlh.=" wgs_genome_territory," if defined($bq->{ wgs_genome_territory } );
		$sqlh.=" wgs_mean_COVERAGE," if defined($bq->{ wgs_mean_coverage  } );   
 		$sqlh.=" wgs_sd_COVERAGE," if defined($bq->{ wgs_sd_coverage } );
 		$sqlh.=" wgs_median_COVERAGE," if defined($bq->{ wgs_median_coverage } );
 		$sqlh.=" wgs_mad_COVERAGE," if defined($bq->{ wgs_mad_coverage } );
 		$sqlh.=" wgs_pct_EXC_MAPQ ," if defined($bq->{ wgs_pct_exc_mapq } );
 		$sqlh.=" wgs_pct_EXC_DUPE," if defined($bq->{ wgs_pct_exc_dupe } );
 		$sqlh.=" wgs_pct_EXC_UNPAIRED," if defined($bq->{ wgs_pct_exc_unpaired } );
 		$sqlh.=" wgs_pct_EXC_BASEQ," if defined($bq->{ wgs_pct_exc_baseq } );
 		$sqlh.=" wgs_pct_EXC_OVERLAP," if defined($bq->{ wgs_pct_exc_overlap } );
 		$sqlh.=" wgs_pct_EXC_CAPPED," if defined($bq->{ wgs_pct_exc_capped } );
 		$sqlh.=" wgs_pct_EXC_TOTAL," if defined($bq->{ wgs_pct_exc_total } );
 		$sqlh.=" wgs_pct_5X," if defined($bq->{ wgs_pct_5X } );
 		$sqlh.=" wgs_pct_10X," if defined($bq->{ wgs_pct_10X } );
 		$sqlh.=" wgs_pct_15X," if defined($bq->{ wgs_pct_15X } );
 		$sqlh.=" wgs_pct_20X," if defined($bq->{ wgs_pct_20X } );
 		$sqlh.=" wgs_pct_25X," if defined($bq->{ wgs_pct_25X } );
 		$sqlh.=" wgs_pct_30X," if defined($bq->{ wgs_pct_30X } );
 		$sqlh.=" wgs_pct_40X," if defined($bq->{ wgs_pct_40X } );
 		$sqlh.=" wgs_pct_50X," if defined($bq->{ wgs_pct_50X } );
 		$sqlh.=" wgs_pct_60X," if defined($bq->{ wgs_pct_60X } );
 		$sqlh.=" wgs_pct_70X," if defined($bq->{ wgs_pct_70X } );
 		$sqlh.=" wgs_pct_80X," if defined($bq->{ wgs_pct_80X } );
 		$sqlh.=" wgs_pct_90X," if defined($bq->{ wgs_pct_90X } );
 		$sqlh.=" wgs_pct_100X," if defined($bq->{ wgs_pct_100X } );
 		$sqlh.=" wgs_coverage," if defined($bq->{ wgs_coverage } );





	chop($sqlh); # remove the last comma	
		$sqlh.=")=( ";
		$sqlh.=" '{". join(",",@{ $bq->{insertsize }})   ."}','{". join(",",@{$bq->{insertsizecount}})."}  ', " if(defined($bq->{insertsize}));
		$sqlh.=" $bq->{median_insert_size}, " if(defined($bq->{median_insert_size}));
		$sqlh.="$bq->{median_dev_insert_size}, " if(defined($bq->{median_dev_insert_size}));
		$sqlh.="$bq->{min_insert_size}, " if(defined($bq->{min_insert_size}));
		$sqlh.="$bq->{max_insert_size}, " if(defined($bq->{max_insert_size}));
		$sqlh.="$bq->{mean_insert_size}, " if(defined($bq->{mean_insert_size}));
		$sqlh.="$bq->{sdev_insert_size}, " if(defined($bq->{sdev_insert_size}));
		$sqlh.=" '{ ".  join(",",@{$bq->{chromosomename}}). "}' , '{".join(",",@{$bq->{aligned}})."}' , " if(defined($bq->{chromosomename}));
		$sqlh.=" $bq->{pf_bases}, " if(defined($bq->{pf_bases}));
		$sqlh.=" $bq->{pf_aligned_bases}, " if(defined($bq->{pf_aligned_bases}));
		$sqlh.=" $bq->{ribosomal_bases}, " if(defined($bq->{ribosomal_bases}));
		$sqlh.=" $bq->{coding_bases}, " if(defined($bq->{coding_bases}));
		$sqlh.=" $bq->{utr_bases}, " if(defined($bq->{utr_bases}));
		$sqlh.=" $bq->{intronic_bases}, " if(defined($bq->{intronic_bases}));
		$sqlh.=" $bq->{intergenic_bases}, " if(defined($bq->{intergenic_bases}));
		$sqlh.=" $bq->{ignored_reads}, " if(defined($bq->{ignored_reads}));
		$sqlh.=" $bq->{correct_strand_reads}, " if(defined($bq->{correct_strand_reads}));
		$sqlh.=" $bq->{incorrect_strand_reads}, " if(defined($bq->{incorrect_strand_reads}));
		$sqlh.=" $bq->{median_cv_coverage}, " if(defined($bq->{median_cv_coverage}));
		$sqlh.=" $bq->{median_5prime_bias}, " if(defined($bq->{median_5prime_bias}));
		$sqlh.=" $bq->{median_3prime_bias}, " if(defined($bq->{median_3prime_bias}));
		$sqlh.=" '{". join(",", @{$bq->{norm_coverage}})."}', " if(defined($bq->{norm_coverage}));
		$sqlh.=" '{". join(",", @{$bq->{total_reads}})."}', " if(defined($bq->{total_reads}));
		$sqlh.="'{". join(",", @{$bq->{pf_reads}})."}', " if(defined($bq->{pf_reads}));
		$sqlh.="'{". join(",", @{$bq->{pf_noise_reads}})."}', " if(defined($bq->{pf_noise_reads}));
		$sqlh.="'{". join(",", @{$bq->{pf_reads_aligned}})."}', " if(defined($bq->{pf_reads_aligned}));
		$sqlh.="'{". join(",", @{$bq->{pf_hq_aligned_reads}})."}', " if(defined($bq->{pf_hq_aligned_reads}));
		$sqlh.="'{". join(",", @{$bq->{pf_hq_aligned_bases}})."}', " if(defined($bq->{pf_hq_aligned_bases}));
		$sqlh.="'{". join(",", @{$bq->{pf_hq_aligned_q20_bases}})."}', " if(defined($bq->{pf_hq_aligned_q20_bases}));
		$sqlh.="'{". join(",", @{$bq->{pf_hq_median_mismatches}})."}', " if(defined($bq->{pf_hq_median_mismatches}));
		$sqlh.="'{". join(",", @{$bq->{mean_read_length}})."}', " if(defined($bq->{mean_read_length}));
		$sqlh.="'{". join(",", @{$bq->{reads_aligned_in_pairs}})."}', " if(defined($bq->{reads_aligned_in_pairs}));
		$sqlh.="'{". join(",", @{$bq->{bad_cycles}})."}', " if(defined($bq->{bad_cycles}));
		$sqlh.="$bq->{estimated_library_size}, " if(defined($bq->{estimated_library_size}));
		$sqlh.="$bq->{unpaired_reads_examined}, " if(defined($bq->{unpaired_reads_examined}));
		$sqlh.="$bq->{read_pairs_examined}, " if(defined($bq->{read_pairs_examined}));
		$sqlh.="$bq->{umapped_reads}, " if(defined($bq->{umapped_reads}));
		$sqlh.="$bq->{unpaired_read_duplicates}, " if(defined($bq->{unpaired_read_duplicates}));
		$sqlh.="$bq->{read_pair_duplicates}, " if(defined($bq->{read_pair_duplicates}));
		$sqlh.="$bq->{read_pair_optical_duplicates}, " if(defined($bq->{read_pair_optical_duplicates}));
		$sqlh.="'$bq->{filename}', " if(defined($bq->{filename}));
			
	 	$sqlh.="$bq->{genome_size}," if defined($bq->{ genome_size});
 		$sqlh.="$bq->{bait_territory}," if defined($bq->{  bait_territory});
 		$sqlh.="$bq->{target_territory}," if defined($bq->{          target_territory});
 		$sqlh.="$bq->{bait_design_efficiency}," if defined($bq->{       bait_design_efficiency});     
 		$sqlh.="$bq->{on_bait_bases}," if defined($bq->{   on_bait_bases});
 		$sqlh.="$bq->{near_bait_bases}," if defined($bq->{  near_bait_bases});
 		$sqlh.="$bq->{off_bait_bases}," if defined($bq->{  off_bait_bases});
 		$sqlh.="$bq->{on_target_bases}," if defined($bq->{ on_target_bases});
 		$sqlh.="$bq->{pct_selected_bases}," if defined($bq->{      pct_selected_bases});
 		$sqlh.="$bq->{pct_off_bait}," if defined($bq->{    pct_off_bait});
 		$sqlh.="$bq->{on_bait_vs_selected}," if defined($bq->{  on_bait_vs_selected});
 	        $sqlh.="$bq->{mean_bait_coverage}," if defined($bq->{      mean_bait_coverage});
 	        $sqlh.="$bq->{mean_target_coverage}," if defined($bq->{    mean_target_coverage});
 	        $sqlh.="$bq->{pct_usable_bases_on_bait}," if defined($bq->{        pct_usable_bases_on_bait});
 	        $sqlh.="$bq->{pct_usable_bases_on_target}," if defined($bq->{     pct_usable_bases_on_target });
 	        $sqlh.="$bq->{fold_enrichment}," if defined($bq->{ fold_enrichment});
 	        $sqlh.="$bq->{zero_cvg_targets_pct}," if defined($bq->{    zero_cvg_targets_pct});
 	        $sqlh.="$bq->{fold_80_base_penalty}," if defined($bq->{     fold_80_base_penalty});
 	        $sqlh.="$bq->{pct_target_bases_2x}," if defined($bq->{         pct_target_bases_2x});
 	        $sqlh.="$bq->{pct_target_bases_10x}," if defined($bq->{     pct_target_bases_10x});
 	        $sqlh.="$bq->{pct_target_bases_20x}," if defined($bq->{     pct_target_bases_20x});
 	        $sqlh.="$bq->{pct_target_bases_30x}," if defined($bq->{     pct_target_bases_30x});
 	        $sqlh.="$bq->{pct_target_bases_40x}," if defined($bq->{     pct_target_bases_40x});
 	        $sqlh.="$bq->{pct_target_bases_50x}," if defined($bq->{     pct_target_bases_50x});
 	        $sqlh.="$bq->{pct_target_bases_100x}," if defined($bq->{    pct_target_bases_100x});
 	        $sqlh.="$bq->{hs_library_size}," if defined($bq->{ hs_library_size});
 	        $sqlh.="$bq->{hs_penalty_10x}," if defined($bq->{      hs_penalty_10x});
 	        $sqlh.="$bq->{hs_penalty_20x}," if defined($bq->{   hs_penalty_20x});
 	        $sqlh.="$bq->{hs_penalty_30x}," if defined($bq->{   hs_penalty_30x});
 	        $sqlh.="$bq->{hs_penalty_40x}," if defined($bq->{   hs_penalty_40x});
 	        $sqlh.="$bq->{hs_penalty_50x}," if defined($bq->{   hs_penalty_50x});
 	        $sqlh.="$bq->{hs_penalty_100x}," if defined($bq->{  hs_penalty_100x});
 	        $sqlh.="$bq->{at_dropout}," if defined($bq->{       at_dropout});
 	        $sqlh.="$bq->{gc_dropout}," if defined($bq->{gc_dropout});
	
		$sqlh.=" $bq->{xenograft_graft_reads}," if defined($bq->{xenograft_graft_reads});
                $sqlh.=" $bq->{xenograft_host_reads}," if defined($bq->{xenograft_host_reads});
                $sqlh.=" $bq->{xenograft_grafthost_reads}," if defined($bq->{xenograft_grafthost_reads});


	$sqlh.=" $bq->{rrnacov_mean}, " if defined($bq->{rrnacov_mean});
        $sqlh.=" $bq->{rrnacov_median}, " if defined($bq->{rrnacov_median});
        $sqlh.=" $bq->{rrnacov_stdev}, " if defined($bq->{rrnacov_stdev});
        $sqlh.=" $bq->{rrnacov_max}, " if defined($bq->{rrnacov_max});
        $sqlh.=" $bq->{rrnacov_min}, " if defined($bq->{rrnacov_min});
        $sqlh.=" $bq->{rrnacov_pct5}, " if defined($bq->{rrnacov_pct5});
        $sqlh.=" $bq->{rrnacov_pct25}, " if defined($bq->{rrnacov_pct25});
        $sqlh.=" $bq->{rrnacov_pct50}, " if defined($bq->{rrnacov_pct50});
        $sqlh.=" $bq->{rrnacov_pct75}, " if defined($bq->{rrnacov_pct75});
        $sqlh.=" $bq->{rrnacov_pct95}, " if defined($bq->{rrnacov_pct95});

		$sqlh.=" $bq->{homer_taggccontent}, " if defined($bq->{homer_taggccontent});
		$sqlh.=" $bq->{homer_taggccount}, " if defined($bq->{homer_taggccount});
		$sqlh.=" $bq->{homer_genomegccontent}, " if defined($bq->{homer_genomegccontent});
		$sqlh.=" $bq->{homer_genomegccount}, " if defined($bq->{homer_genomegccount});
		$sqlh.=" $bq->{homer_fragment_length}, " if defined($bq->{homer_fragment_length});
		$sqlh.=" $bq->{homer_peak_width}, " if defined($bq->{homer_peak_width});
		$sqlh.=" $bq->{homer_tagdistance}, " if defined($bq->{homer_tagdistance});
		$sqlh.=" $bq->{homer_tagautocorrelation_samestrand}, " if defined($bq->{homer_tagautocorrelation_samestrand});
		$sqlh.=" $bq->{homer_tagautocorrelation_oppositestrand}, " if defined($bq->{homer_tagautocorrelation_oppositestrand});
		$sqlh.=" $bq->{homer_tags_position}, " if defined($bq->{homer_tags_position});
		$sqlh.=" $bq->{homer_tags_per_position}, " if defined($bq->{homer_tags_per_position});


chop( $sqlh );chop($sqlh); #remove the last comma
		$sqlh.=")where sample_id=$sample_id and flag='$flag'
		";
		$logger->info("updateAlignmentQC: executing \n$sqlh");
		$dbh->do( $sqlh );
	
}


sub updateReadQC{
	my($fq,$sample_id,$flag,$dbhParam)=@_;
	if(!defined($flag)){$flag='original';}
	if( ref( $fq )=~/ARRAY/){
		$logger->warn("Instead of a hash I received an array reference. Converting array to hash assuming key/value sequences");
		my @tmp=@$fq;
		my %tmp=@tmp;
		$fq= \%tmp;
	}
	my $dbh;
	if(!defined($dbhParam)){
		$dbh=Celgene::Utils::DatabaseFunc::connectDB();
	}else{
		$dbh=$dbhParam;
	}
	$logger->info("updateReadQC: Connecting to database");
	$logger->trace( Dumper( $fq ));
	
	my $sql="update sample_readqc 	set ( ";
	$sql.=" sequenced_reads, " if defined( $fq->{totalsequences});
	$sql.=" read_quality_median, " if defined( $fq->{median});
	$sql.=" read_quality_mean, " if defined( $fq->{mean});
	$sql.=" read_quality_gc, " if defined( $fq->{GC});
	$sql.=" read_quality_n, " if defined( $fq->{N});
	$sql.=" read_qc_ninetypercentile, " if defined( $fq->{ninetypercentile});
	$sql.=" read_qc_tenpercentile, " if defined( $fq->{tenpercentile});
	$sql.=" read_qc_upperquartile, " if defined( $fq->{upperquartile});
	$sql.=" read_qc_lowerquartile, " if defined( $fq->{lowerquartile});
	$sql.=" sequence_length, " if defined( $fq->{sequencelength});
	$sql.=" encoding, " if defined( $fq->{encoding});
	$sql.=" lanes, " if defined( $fq->{lanes});
	$sql.=" lanes_reads, " if defined( $fq->{lanes_reads});
	$sql.=" adapter, " if defined( $fq->{adapter});
	$sql.=" trimming_events, " if defined( $fq->{trimming_events});
	$sql.=" trimmed_reads, " if defined( $fq->{trimmed_reads});
	$sql.=" trimmed_bases, " if defined( $fq->{trimmed_bases});
	$sql.=" quality_trimmed_bases, " if defined( $fq->{quality_trimmed_bases});
	$sql.=" too_short_reads, " if defined( $fq->{too_short_reads});
	$sql.=" too_long_reads, " if defined( $fq->{too_long_reads});
	$sql.=" trimmed_length, " if defined( $fq->{trimmed_length});
	$sql.=" trimmed_count, " if defined( $fq->{trimmed_count});
	$sql.=" trimmed_expected, " if defined( $fq->{trimmed_expected});
	$sql.=" spike_correlation, " if defined($fq->{spike_correlation});
	$sql.=" spike_min_concentration, " if defined($fq->{spike_min_concentration});
	$sql.=" spike_reads, " if defined($fq->{spike_reads});
		chop($sql);chop($sql);
		$sql.=")=(";
		$sql.="'{ $fq->{totalsequences}->[0], $fq->{totalsequences}->[1]   }'," if defined( $fq->{totalsequences});
		$sql.="'{ { ".join(",",@{$fq->{median}->[0]})." } ,   {". join(",",@{$fq->{median}->[1]}). "}    }'  , " if defined( $fq->{median});
		$sql.="'{ { ".join(",",@{$fq->{mean}->[0]})  ." } ,   {". join(",",@{$fq->{mean}->[1]})  . "}    }'  , " if defined( $fq->{mean});
		$sql.="'{ { ".join(",",@{$fq->{GC}->[0]})    ." } ,   {". join(",",@{$fq->{GC}->[1]})    . "}    }'  , " if defined( $fq->{GC});
		$sql.="'{ { ".join(",",@{$fq->{N}->[0]})     ." } ,   {". join(",",@{$fq->{N}->[1]})     . "}    }' , " if defined( $fq->{N});
		$sql.="'{ { ".join(",",@{$fq->{ninetypercentile}->[0]})." } ,   {". join(",",@{$fq->{ninetypercentile}->[1]}). "}    }'  , " if defined( $fq->{ninetypercentile});
		$sql.="'{ { ".join(",",@{$fq->{tenpercentile}->[0]})  ." } ,   {". join(",",@{$fq->{tenpercentile}->[1]})  . "}    }'  , " if defined( $fq->{tenpercentile});
		$sql.="'{ { ".join(",",@{$fq->{upperquartile}->[0]})    ." } ,   {". join(",",@{$fq->{upperquartile}->[1]})    . "}    }'  , " if defined( $fq->{upperquartile});
		$sql.="'{ { ".join(",",@{$fq->{lowerquartile}->[0]})     ." } ,   {". join(",",@{$fq->{lowerquartile}->[1]})     . "}    }' , " if defined( $fq->{lowerquartile});
		$sql.="$fq->{sequencelength}, " if defined( $fq->{sequencelength});
		$sql.="'$fq->{encoding}', " if defined( $fq->{encoding});
		$sql.="'{". join(",",@{$fq->{lanes}}) . "}' , " if defined( $fq->{lanes});
		$sql.="'{". join(",",@{$fq->{lanes_reads}}). "}' , " if defined( $fq->{lanes_reads});
		$sql.="'{ \"$fq->{adapter}->[0]\", \"$fq->{adapter}->[1]\"}', " if defined( $fq->{adapter});
		$sql.="'{ $fq->{trimming_events}->[0], $fq->{trimming_events}->[1] }', " if defined( $fq->{trimming_events});
		$sql.="'{ $fq->{trimmed_reads}->[0], $fq->{trimmed_reads}->[1]} ', " if defined( $fq->{trimmed_reads});
		$sql.="'{ $fq->{trimmed_bases}->[0], $fq->{trimmed_bases}->[1]} ', " if defined( $fq->{trimmed_bases});
		$sql.="'{ $fq->{quality_trimmed_bases}->[0], $fq->{quality_trimmed_bases}->[1]} '," if defined($fq->{quality_trimmed_bases}); 
		$sql.="'{ $fq->{too_short_reads}->[0], $fq->{too_short_reads}->[1] }', " if defined( $fq->{too_short_reads});
		$sql.="'{ $fq->{too_long_reads}->[0], $fq->{too_long_reads}->[1] }', " if defined( $fq->{too_long_reads});
		$sql.="'{ {". join(",", @{$fq->{trimmed_length}->[0]}) ." } , { " . join(",", @{$fq->{trimmed_length}->[1]}) ."} } ', " if defined( $fq->{trimmed_length});
		$sql.="'{ {". join(",", @{$fq->{trimmed_count}->[0]}) ." } , { " . join(",", @{$fq->{trimmed_count}->[1]}) ."} } ', " if defined( $fq->{trimmed_count});
		$sql.="'{ {". join(",", @{$fq->{trimmed_expected}->[0]}) ." } , { " . join(",", @{$fq->{trimmed_expected}->[1]}) ."} } ', " if defined( $fq->{trimmed_expected});
		$sql.="$fq->{spike_correlation}, " if defined($fq->{spike_correlation});
		$sql.="$fq->{spike_min_concentration}, " if defined($fq->{spike_min_concentration});
		$sql.="$fq->{spike_reads}, " if defined($fq->{spike_reads});

	chop $sql;chop $sql;
	$sql.=") where sample_id=$sample_id and flag='$flag'";
	$logger->info("updateReadQC: executing \n$sql");
	$dbh->do( $sql );
	
}

# run an sql query to return basic metrics for the QC of a sample
sub getQCReportTable{
	my($sample_id,$flag,$dbhParam)=@_;
	if(!defined($flag)){$flag='original';}
	my $sql=qq{
	select si.sample_id,si.display_name,pi.project_name,
	sr.sequenced_reads[1] as sequenced_Reads_R1,
	sr.sequenced_reads[2] as sequenced_Reads_R2,
	sr.spike_correlation,sr.spike_min_concentration,
	sr.trimmed_reads[1] as trimmed_reads_R1, sr.trimmed_reads[2] as trimmed_reads_R2,
	sa.reads_aligned_in_pairs[1] as reads_aligned_in_pairs_R1,
	sa.reads_aligned_in_pairs[2] as reads_aligned_in_pairs_R2,
	sa.correct_strand_reads,sa.incorrect_strand_reads,
	log(cast(sa.correct_strand_reads as float)/ NULLIF( cast(sa.incorrect_strand_reads as float),0 ) ) as strandness_index,
	sa.median_cv_coverage, sa.median_5prime_bias, sa.median_3prime_bias,
	sa.median_insert_size,sa.median_dev_insert_size,
	sa.estimated_library_size,
	sa.read_pair_duplicates,sa.unpaired_read_duplicates,sa.read_pair_optical_duplicates,
	cast( ( sa.read_pair_duplicates + sa.unpaired_read_duplicates ) as float)/ cast(sr.sequenced_reads[1] as float) as duplication_index,
	cast( ( sa.read_pair_optical_duplicates  ) as float)/ cast(sr.sequenced_reads[1] as float) as optical_duplication_index,
	cast( sa.estimated_library_size as float) / cast( sr.sequenced_reads[1] as float)  as complexity_index,
	cast( sa.ribosomal_bases as float)/1000000 as ribosomal_bases_M, 
	cast( sa.utr_bases as float) /1000000 as utr_bases_M, 
	cast( sa.coding_bases as float) /1000000 as coding_bases_M, 
	cast( sa.intronic_bases as float)/1000000 as intronic_bases_M, 
	cast( sa.intergenic_bases as float)/1000000 as intergenic_bases_M,
	cast( sa.ribosomal_bases as float)/cast( sa.ribosomal_bases+ sa.utr_bases+ sa.coding_bases+ sa.intronic_bases+ sa.intergenic_bases as float) as ribosomal_contamination
	from sample_info si
	join project_info pi on pi.project_id=si.project_id
	join sample_alignmentqc sa on sa.sample_id=si.sample_id and sa.flag='$flag'
	join sample_readqc sr on sr.sample_id=si.sample_id and sr.flag='$flag'
	where si.sample_id=$sample_id 
	};
	
	my $dbh;
        if(!defined($dbhParam)){
                $dbh=Celgene::Utils::DatabaseFunc::connectDB();
        }else{
                $dbh=$dbhParam;
        }
        $logger->info("getQCReportTable: Connecting to database");
	$logger->debug("getQCReportTable: Executing SQL\n$sql");
	
	my $cur=$dbh->prepare($sql);
	$cur->execute();
	my $hash_ref=$cur->fetchrow_hashref();
	
	$logger->trace( "getQCReportTable: Query returns:\n". Dumper( $hash_ref ) );
	return $hash_ref;

}

sub getProjectIDList{
	my($dbhParam)=@_;
        my $dbh;
        if(!defined($dbhParam)){
                $dbh=Celgene::Utils::DatabaseFunc::connectDB();
        }else{
                $dbh=$dbhParam;
        }
        $logger->info("getProjectIDList: Connecting to database");

	# get the project information from the database
	my $sql=qq{
		select distinct si.project_id , pi.project_name, pi2.project_name as synonym_project,si.vendor_project_name,
		tcv.technology, 
		ecv1.experiment_type,vcv.vendor,se.stranded, se.paired_end,se.exome_bait_set,ecv2.experiment_prep_method as RNA_selection,
		ecv3.experiment_prep_method as library_prep
		from sample_info si
		join project_info pi on si.project_id=pi.project_id
		join sample_experiment se on si.sample_id=se.sample_id
		join technology_cv tcv on se.technology=tcv.technology_id
		join experiment_type_cv ecv1 on se.experiment_type=ecv1.experiment_type_id
		join vendor_cv vcv on se.vendor=vcv.vendor_id
		left join experiment_prep_method_cv ecv2 on se.rna_selection=ecv2.experiment_prep_method_id
		left join experiment_prep_method_cv ecv3 on se.library_prep=ecv3.experiment_prep_method_id
		left join project_relations pr on pi.project_id=pr.child_id
		left join project_info pi2 on pi2.project_id=pr.project_id
		order by si.project_id asc

	};
	my $cur=$dbh->prepare($sql);
	$cur->execute;
	$cur->{RaiseError}=1;
	my $array_ref=$cur->fetchall_arrayref;
	my $col_names=$cur->{NAME_uc};
	$cur->finish;

	return ($array_ref, $col_names);
		
}

1;
