package celgeneExecPrograms;
use strict;
use warnings;


# example functions
sub parsesamtoolsExample{
	my($command,$hash,$binary)=@_;
	push @{$hash->{generator_version}}, getVersionS( $binary );
}

sub parseSTARExample{
	my($command,$hash,$binary)=@_;
	push @{$hash->{generator_version}}, 'STAR[2.3.1r]';
}

sub parsebowtie2Example{
	my($command,$hash,$binary)=@_;
	if($command =~/-x\s+(\S+)/){ $hash->{reference}=$1;}
	push @{$hash->{generator_version}},getVersionDD( $binary );
	while ($command =~/-S\s+(\S+)/){ push @{$hash->{output}}, $1; }
	#bowtie2 [options]* -x <bt2-idx> {-1 <m1> -2 <m2> | -U <r>} [-S <sam>]
  	#<bt2-idx>  Index filename prefix (minus trailing .X.bt2).
  	#<m1>       Files with #1 mates, paired with files in <m2>.
  	#<m2>       Files with #2 mates, paired with files in <m1>.
  	#<r>        Files with unpaired reads.
  	#<sam>      File for SAM output (default: stdout)
}

sub parseHTSeqExample{
	my($command,$hash,$binary)=@_;
	push @{$hash->{generator_version}},getVersionS( $binary );

}
sub parseCufflinksExample{
	my($command,$hash,$binary)=@_;

	push @{$hash->{generator_version}},getVersionS( $binary );

}
sub  parseMACSExample{
	my($command,$hash,$binary)=@_;
	push @{$hash->{generator_version}},getVersionDD( $binary );
	if($command =~/-n\s+(\S+)/){ push @{$hash->{possiblefiles}}, $1;}
	else{ push @{$hash->{possiblefiles}}, 'NA';} 
	$hash->{filecollection}=1;
#	macs14 -- Model-based Analysis for ChIP-Sequencing
#   Options:
#  --version             show program's version number and exit
#  -h, --help            show this help message and exit.
#  -t TFILE, --treatment=TFILE
#                        ChIP-seq treatment files. REQUIRED. When ELANDMULTIPET
#                        is selected, you must provide two files separated by
#                        comma, e.g.
#                        s_1_1_eland_multi.txt,s_1_2_eland_multi.txt
#  -c CFILE, --control=CFILE
#                        Control files. When ELANDMULTIPET is selected, you
#                        must provide two files separated by comma, e.g.
#                        s_2_1_eland_multi.txt,s_2_2_eland_multi.txt
#  -n NAME, --name=NAME  Experiment name, which will be used to generate output
#                        file names. DEFAULT: "NA"
#	
}

# need to know this information from the command line
#"file=s"=>\$file, 
#	"collection=s"=>\$collection,
#	"inherits=s"=>\$inheritsFile,
#	"derived_from=s"=>\$derived_from,
#	"description=s"=>\$description,
#	"filetype=s"=>\$filetype,
#	"project=s"=>\$project,
#	"subproject=s"=>\$subproject,
#	"project_type=s"=>\$project_type,
#	"sample_id=s"=>\$sample_id,
#	"generator=s"=>\$generator,
#	"generator_version=s"=>\$generator_version,
#	"generator_string=s"=>\$generator_string,
#	"reference=s"=>\$refdatabase,
#	"reference_version=s"=>\$refdatabase_version,
	


1;