package configParser;
use strict;
use warnings;
use Celgene::Utils::FileFunc;
use Celgene::Utils::ArrayFunc;
use File::Spec;
use File::Basename;
use fileObj;
use Time::localtime;
use File::stat;
use threads;
use Exporter;
use Data::Dumper;

use Cwd 'abs_path';

sub new
{
    my $class = shift;
    my $filename=shift;
	my $self = {};
    bless $self, $class;
	
	
    
    $self->{logger}=Log::Log4perl->get_logger("configParser");
   
   	# look for a file under $HOME/.metadata.config
   	# or in the same directory where the script is look for metadata config
   	
   	my $home=$ENV{HOME};
   	$self->{logger}->debug("configParser: looking for config file in \n".
   							"\t\t$home/.metadata.config \n".
   							"\t\t".File::Basename::dirname( abs_path($0) )."/metadata.config");
   	if( -e "$home/.metadata.config"){
   		$self->loadFile( "$home/.metadata.config");
   	}elsif ( -e File::Basename::dirname(abs_path( $0 ))."/metadata.config"){
   		$self->loadFile(File::Basename::dirname( abs_path($0) )."/metadata.config");
   	}
   	
    return $self;
}

sub loadFile{
	my ($self,$fn)=@_;
	$self->{logger}->debug("configParser: Loading config file $fn");
	
	
	my $fh=Celgene::Utils::FileFunc::newReadFileHandle( $fn );
	while(my $line=<$fh>){
		chomp $line;
		$self->{logger}->trace("loadFile: parsing line $line");
		if($line=~/^#/ or $line=~/^;/){ $self->{logger}->trace("loadFile: skipping comment line");next; }
		
		my($key,$value)=split('=',$line);
		if(!defined($key) or !defined($value)){next;}
		$self->{logger}->trace("loadFile: key [$key], value [$value]");
		
		# parse composite vlaues
		if( $value =~/\,/ ){
			my($innerKey,$innerValue)=split(",",$value);
			$self->{logger}->trace("loadFile: Inner  key [$innerKey], value [$innerValue]");
			$self->{$key}->{$innerKey}=$innerValue;
		}else{
			$self->{$key}=$value;
		}	
	}
	close($fh);
	
	$self->{logger}->trace( Dumper( $self ) );
}

1;