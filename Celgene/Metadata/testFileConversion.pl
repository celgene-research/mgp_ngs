use strict;
use warnings;
use Celgene::Metadata::FileConversion;
use Log::Log4perl;
my $logger=setUpLog();

## from AWS to local (UNIX)
#my $from="s3://celgene-ngs-data/Processed/DA0000124/RNA-Seq.1/STARaln.human-bamfiles_1435388372/GDM-1_1.coord.bam";
#my $to=fileConversion::_convertfn( $from , 'aws','linux');
#print "from: $from\nto   :$to\n";

## from  local (UNIX) to AWS
#my $from="/home/kmavrommatis/S3/Processed/DA0000124/RNA-Seq.1/STARaln.human-bamfiles_1435388372/GDM-1_1.coord.bam";
#my $to=fileConversion::_convertfn( $from ,'linux', 'aws');
#print "from: $from\nto   :$to\n";


## automatic conversion based on OS
#
#my $from="C:/Users/kmavrommatis/Documents/test.docx";
#my $to=fileConversion::cf( $from);
#print "from: $from\nto :$to\n";



# manual conversion to AWS

my $from="/home/kmavrommatis/S3/Processed/DA0000124/RNA-Seq.1/STARaln.human-bamfiles_1435388372/GDM-1_1.coord.bam";
my $to=FileConversion::cf( $from , 'toaws');
print "from: $from\nto :$to\n";














sub setUpLog{
	
	my $logConf=qq{
		log4perl.rootLogger          = DEBUG,  Screen
	    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
	    log4perl.appender.Screen.stderr  = 0
	    log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
	    log4perl.appender.Screen.layout.ConversionPattern = [%p : %c - %d] - %m{chomp}%n
	};
	Log::Log4perl->init(\$logConf);
	return $logger;
}
