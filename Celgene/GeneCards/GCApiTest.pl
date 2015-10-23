#==============================================================================
#
# 				GeneCards API Test Application
#
# Copyright LifeMap Sciences, Inc., all rights reserved
#
#==============================================================================

use Celgene::GeneCards::GeneCards;
use JSON;
use Data::Dumper;
use Log::Log4perl qw(:easy);

# Initialize logger. Use $DEBUG to see initialization parameters, 
# JSON request & response, and dump the data structure of the result
Log::Log4perl->easy_init($ERROR);

# Initialize logger
my $logger = Log::Log4perl->get_logger('GCApiTest');

# Initialize API
my $api = new GeneCards(
	'[UserName]', 	# Your UserName
	'[ApiKey]'		# Your API Key
);

# Prepare query
# List of gene symbols
my @genes = ( 'TP53', 'JUN' );

# Field configuration - see documentation for complete list & parameters
my @fields = (
	{ Name =>	'Aliases' 	}, 
	{ Name =>	'Summaries' },
	{ Name =>   'GO'        },
	{ Name =>   'HGNC'      }
);

# Execute query
my $result = $api->getGenesData(\@genes, \@fields);

# Result OK? If not, die with error
if ($result->{Result} eq JSON::false) {
	die("ERROR: $result->{Message}");
}

# As an example, print the first summary text for the JUN gene
print $result->{Data}{TP53}{Summaries}[0]{Value};

# You can use the below to print out the complete result data structure
# print Data::Dumper->Dumper($result);
