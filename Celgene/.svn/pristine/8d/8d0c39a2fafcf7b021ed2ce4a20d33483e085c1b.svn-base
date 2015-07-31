package  VCFparser;

# TODO
# Finish parsing of FORMAT and GENOTYPE fields

use strict;
use warnings;
use Log::Log4perl;
use ArrayFunc;
use FileFunc;

# my $vcf=new VCFparser( -vcf => $filename )
#while( my $rec=$vcf->nextRecord()){
#	
#}

sub new{
	my($class,@arguments)=@_;
	my $self={};
	bless($self,$class);
	$self->{logger}=Log::Log4perl->get_logger('VCFparser');
	my $filename;
	for(my $i=0;$i<scalar(@arguments);$i++){
		$self->{logger}->debug("Processing argument ", $arguments[$i]);
		if( $arguments[$i] eq '-vcf'){
			$filename=$arguments[++$i];
			$self->openFile($filename);
		}
	}
	
	
	return($self);
}

sub openFile{
	my($self, $filename)=@_;
	my $rfh=FileFunc::newReadFileHandle( $filename );
	$self->{logger}->debug("Accessing file $filename");	
	$self->{inputVCF}=$rfh;
}

sub DESTROY{
	my($self)=@_;
	my $rfh=$self->{ inputVCF};
	close($rfh);
}
sub nextRecord{
	my($self)=@_;
	
	my $rfh=$self->{ inputVCF };
	while(my $line=<$rfh>) {
		chomp $line;
		if($line=~/^#CHROM/){
			my($chrom,$pos, $id,$ref,$alt,$qual,$filter,$info,$format, @samplenames)=split("\t",$line);
			$self->sampleNames( \@samplenames );
			$self->{logger}->trace("Got sample names ", join(" ",@samplenames));
		}
		next if($line=~/^#/); # for the time ignore parsing any header infor
		
		my $VCFRecord=VCFRecord->new( $line );
		$self->{record}=$VCFRecord;
		
		return $self->{record};		
	}
	return undef;
	
}

sub sampleNames{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{id}=$value;
	}
	return $self->{id};
}


return 1;

package VCFRecord;
#use this package to process one line in the gtf file at a time
our %impactHash={ 'LOW' => 1, 'MODIFIER'=>2, 'MODERATE'=>3, 'HIGH'=>4};
sub new{
	my($class,$record)=@_;
	my $self={};
	bless($self,$class);
	$self->{effectindex}=-1;
	$self->{logger}=Log::Log4perl->get_logger('VCFRecord');
	$self->{VCFLine}=$record;
	$self->parseRecord();
	return($self);
}

sub parseRecord{
	my($self)=@_;
	my($chrom,$pos, $id,$ref,$alt,$qual,$filter,$info,$format, @genotypes)=split("\t",$self->{VCFline} );
	
	$self->chromosome($chrom);
	$self->position($pos);
	$self->id( $id );
	$self->reference( $ref );
	$self->allele( $alt );
	$self->quality( $qual );
	$self->filter($filter);
	$self->info( $info );
	$self->format($format);
	$self->genotypes(\@genotypes);

}

sub chromosome{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{chrom}=$value;
	}
	return $self->{chrom};
}
sub position{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{pos}=$value;
	}
	return $self->{pos};
}
sub id{
	my($self,$value)=@_;
	if(defined($value)){
		my @ids=split(",", $value);
		@{$self->{id}}=@ids
	}
	return $self->{id};
}
sub reference{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{ref}=$value;
	}
	return $self->{ref};
}
sub allele{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{alt}=$value;
	}
	return $self->{alt};
}
sub quality{
	my($self,$value)=@_;
	if(defined($value)){
		$self->{qual}=$value;
	}
	return $self->{qual};
}
sub filter{
	my($self,$value)=@_;
	if(defined($value)){
		my @filters=split(",", $value);
		@{$self->{filter}}=@filters;
	}
	return $self->{chrom};
}
sub info{
	my($self,$info)=@_;
	if(defined($info)){
		my @infoFields=split(";",$info);
		foreach my $f(@infoFields){
			my($t1,$t2)=split("=", $f);
			if($t1 eq 'EFF'){
				$self->effect ( $t2 );
			}else{
				$self->{"info_".$t1}=$t2;
			}
		}
		
	}
	return $self->{info};
}

sub format{
	my($self, $value)=@_;
	
}

sub effect{
	my ($self, $effect ,$gatkFlag)=@_;	
	if(defined($effect)){
		my @effects=split(",",$effect);
		for(my $i=0; $i<scalar(@effects);$i++){
			my($fullEffect,$descEff)=split( /\(/, $effects[$i] );
			$self->{logger}->debug("Processing effect $fullEffect -> $descEff");
			my @desc=split('\|', $descEff);
#			print join(" : ", @desc),"\n";
			my($effectImpact, $functionalClass,$codonChange,$aaChange,$geneLength,$geneName,$transcriptBiotType,
				$geneCoding,$transcriptID, $exonIntronBank,$genotypeNumber,$warningsErrors);
			if(defined($gatkFlag)){
				($effectImpact, $functionalClass,$codonChange,$aaChange,$geneName,$transcriptBiotType,
				$geneCoding,$transcriptID, $exonIntronBank,$genotypeNumber,$warningsErrors)=@desc;
				$geneLength=0;
			}else{
				($effectImpact, $functionalClass,$codonChange,$aaChange,$geneLength,$geneName,$transcriptBiotType,
				$geneCoding,$transcriptID, $exonIntronBank,$genotypeNumber,$warningsErrors)=@desc;
			}
			$self->{effect}->[$i]->{Impact}=$effectImpact;
			$self->{effect}->[$i]->{FunClass}= $functionalClass;
			$self->{effect}->[$i]->{CodonChange}= $codonChange;
			$self->{effect}->[$i]->{aaChange}= $aaChange;
			$self->{effect}->[$i]->{geneLength}= $geneLength;
			$self->{effect}->[$i]->{geneName}= $geneName;
			$self->{effect}->[$i]->{transcriptBioType}= $transcriptBiotType;
			$self->{effect}->[$i]->{geneCoding}= $geneCoding;
			$self->{effect}->[$i]->{transcriptID}= $transcriptID;
			$self->{effect}->[$i]->{exonIntronBank}= $exonIntronBank;
			$self->{effect}->[$i]->{genotypeNumber}= $genotypeNumber;
			$self->{effect}->[$i]->{WarnError}= $warningsErrors;
		}
	}
}

sub setLongestEffect{
	my($self)=@_;
	@{ $self->{ effect } } =
		sort{
			$impactHash{ $b->{ Impact } } <=> $impactHash{ $a->{Impact} } ||
			$b->{ geneLength } <=> $a->{geneLength};
		} @{ $self->{ effect } }
	
}
sub setWorstEffect{
	my($self)=@_;
	@{ $self->{ effect } } =
		sort{
			$b->{ geneLength } <=> $a->{geneLength} ||
			$impactHash{ $b->{ Impact } } <=> $impactHash{ $a->{Impact} } ;
		} @{ $self->{ effect } }
}
sub nextEffect{
	my($self)=@_;
	$self->{effectindex}++;
	if($self->{index} == scalar( @{$self->{ effect}})){
		return undef;
	}
}

sub effImpact{
	my($self)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{Impact};
}
sub effFunClass{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{FunClass};
}
sub effCodonChange{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{CodonChange};
}
sub effaaChange{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{aaChange};
}
sub effgeneLength{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{geneLength};
}
sub effgeneName{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{geneName};
}
sub efftransctriptBioType{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{transcriptBioType};
}
sub effgeneCoding{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{geneCoding};
}
sub efftranscriptID{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{transcriptID};
}
sub effexonIntronBank{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{exonIntronBank};
}
sub effgenotypeNumber{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{genotypeNumber};
}
sub effWarnError{
	my($self,$value)=@_;
	return $self->{ effect}->[ $self->{effectindex} ]->{WarnError};
}



return 1;