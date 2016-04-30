package MetadataPrepare;
use strict;
use warnings;
use Log::Log4perl;
use Data::Dumper;
use File::Basename;
use HTML::Entities;
# package to prepare a file that can be further used for ingestion of meta data to a
# data management system like iRODs or OODT

sub new{
	my $class = shift;
    my $self = {};
    bless $self, $class;
    
    
    $self->{logger}=Log::Log4perl->get_logger("metadataPrepare");
   	$self->{ metadata }={};
    return $self;
}


sub awsArguments{
	my($self,$args)=@_;
	if( defined($args) ){
		$self->{awsCommandArgument}=$args;
	}
	if(!defined($self->{awsCommandArgument})){
		$self->{awsCommandArgument}= " ";
	}
	
	return $self->{awsCommandArgument};	
}


sub loadFileIRODS{
	my($self,$filename)=@_;
	open(my $rfh, $filename) or die "Cannot open $filename\n";
	while(my $line=<$rfh>){
		chomp $line;
		my ($key,$value)=split("\t", $line);
		my @vals=split(":", $value);
		foreach my $v(@vals){
			$self->addMetadata($key, $v);
		}
	}
	
	close($rfh);
}
sub loadFileOODT{
	my($self,$filename)=@_;
	if($filename =~/^s3:/){
		my $tmp=$ENV{TMPDIR};
		my $command="aws s3 cp $filename $tmp". basename($filename) ." $self->{awsCommandArgument}" ;
		$self->logger->trace("loadFileOODT: executing command $command");
		system( $command );
		$filename="$tmp". basename($filename);
	}
	open(my $rfh, $filename) or die "Cannot open $filename\n";
	my $line=<$rfh>;
	if($line !~/<cas:metadata xmlns:cas/){
		$self->{logger}->warn("This is not a cas xml file");
		 return undef; 
	}
	my $key;my $val;
	while(my $line=<$rfh>){
		if($line=~/<keyval>/){ $key = $val= "";}
		if($line=~/<key>(.+)?<\/key>/){ $key = $1;}
		if( $line=~/<val>(.+)?<\/val>/){ 
			$val = $1;
			$self->{logger}->debug("For key $key found value $val");
			$self->addMetadata( $key , $val);
		}
		if($line=~/<\/keyval>/){ $key=$val=undef;}
	}
	
	close($rfh);
	if($filename =~/^s3:/){
		unlink($filename);
	}
}

sub addMetadata{
	my($self,$key,$value)=@_;
	if( ref($value) !~/ARRAY/){
		$self->{logger}->debug("addMetadata: metadata for $key are not in array format.Converting..");
		my $t=$value;
		$value=[];
		push @$value, $t;
	}else{
		#print Dumper( $value );
	}
	foreach my $v( @$value){
		$self->{logger}->debug("addMetadata: adding key/value [$key]/[$v]");
		push @{$self->{ metadata }->{ $key }}, $v;
	}
}

sub clearMetadata{
	my($self,$key)=@_;
	$self->{ logger }->debug("clearMetadata: clearing metadata for $key");
	@{$self->{ metadata }->{ $key }}=undef;
	delete $self->{metadata}->{ $key };
}

sub getMetadata{
	my($self,$key)=@_;
	return $self->{metadata}->{$key};
}

sub storeIRODS{
	my($self, $filename)=@_;
	open(my $wfh,">". $filename) or die "Cannot open $filename for writing\n";
	foreach my $key(keys %{$self->{ metadata }}){
		foreach my $value ($self->_unique(  $self->{ metadata }->{$key} )){
			print $wfh $key . "\t". $value. "\n";
		}
	}
	close($wfh);
}

sub storeOODT{
	my($self,$filename)=@_;
	my $originalFilename=$filename;
	if($filename =~/^s3:/){
		$filename="/tmp/". basename($filename);
	}
	
	open(my $wfh,">". $filename) or die "Cannot open $filename for writing\n";
	
	print $wfh "<cas:metadata xmlns:cas=\"http://oodt.jpl.nasa.gov/1.0/cas\">\n";
	
	
	foreach my $key(keys %{$self->{ metadata }}){
		if($key=~/^_/){next;} # these are members of the hash that are not meant to be exposed
		if( !defined(  $self->{metadata}->{$key} )) {next;}
		if(  scalar(  @{$self->{metadata}->{$key}}  )==0){next;}
		print $wfh "\t<keyval>\n";
		print $wfh "\t\t<key>".$key."</key>\n";
		foreach my $value ($self->_unique( $self->{ metadata }->{$key} )){
			$self->{logger}->debug("Changing $value to");
			$value=HTML::Entities::encode_entities( $value );
			$self->{logger}->debug("$value");
			print $wfh "\t\t<val>".$value."</val>\n";
		}
		print $wfh "\t</keyval>\n";
	}
	
	print $wfh "</cas:metadata>\n";
	close($wfh);
	if($originalFilename =~/^s3:/){
		my $command="aws s3 cp $filename $originalFilename  $self->{awsCommandArgument}";
		$self->{logger}->trace("storeOODT: executing command $command");
		system( $command );
		unlink($filename);
	}
}


sub _unique
{
	my ($self,$array)=@_;
	if(!defined($array) ){return undef;}	
	if(scalar(@$array)==1){return @$array;}
        my %check=();
        my @uniq=();

			foreach my $e(@$array)
			{
				if (defined($e))
				{
					unless(defined($check{$e}))
					{
							push @uniq,$e;
							$check{$e}=1;
					}
				}
			}
        return @uniq ;
}


1;
