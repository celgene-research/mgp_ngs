#!/usr/bin/perl 
#==============================================================================
#
# GeneCards API Library
#
# This library provides access to the GeneCards 4.x API. 
# See documentation in pod-generated GeneCards.html for more details.
#
# Copyright LifeMap Sciences, Inc., all rights reserved
#
#==============================================================================
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Log::Log4perl qw(:easy);

package Celgene::GeneCards::GeneCards;

use constant API_EXPORT_URL => "https://api.genecards.org/Api/Export/";

# Initialize logger
my $logger = Log::Log4perl->get_logger('GeneCards');

# Constructor for GeneCards API
sub new {
	my $class = shift;
	my $self = {
		_userName 	=> shift,
		_apiKey		=> shift
	};

	$logger->debug("GeneCards API initialized for $self->{_userName} with API key $self->{_apiKey}");
	
	bless $self, $class;
	return $self;
}

# Function to request data for a set of genes
sub getGenesData() {
	my ($self, $genesRef, $fieldsRef) = @_;

	# Setup connection and JSON Request
	my $ua = new LWP::UserAgent(keep_alive=>1);

	# Build JSON
	my $json = JSON->new->utf8;
	my $genesJson = $json->encode($genesRef);
	my $fieldsJson = $json->encode($fieldsRef);
	
	my $requestJson = "{ UserName: '$self->{_userName}', Key : '$self->{_apiKey}', Genes: $genesJson, Fields: $fieldsJson }";
	$logger->debug("Request JSON: $requestJson\n");
	
	# Post JSON request
	my $req = new HTTP::Request(POST => API_EXPORT_URL);
	$req->content_type("application/x-www-form-urlencoded");
	$req->content($requestJson);
	
	# Check response
	my $response = $ua->request($req);
	if ($response->is_success) {
		$logger->debug("Response JSON: $response->decoded_content");
		my $result = $json->decode($response->decoded_content);

		# Debugging - print result structure using Data::Dumper for debugging purposes
		if ($logger->is_debug()) { $logger->debug(Data::Dumper->Dumper($result)); };
		
		return $result;
	}
	else {
		die $response->status_line;
	}	
}

1;

#################### pod documentation ####################

=head1 NAME

GeneCards.pm - GeneCards API module for Perl

=head1 DESCRIPTION

This library is used to retrieve data using the GeneCards 4.x cloud service. 
Users of this API should first instantiate and configure the API to connect to the service with their credentials (email + API Key). 

=head1 SYNOPSIS

Simple request for retrieving one description for the JUN gene:

	# Initialize API
	my $api = new GeneCards('[Email]','[ApiKey]');

	# Prepare query
	# List of gene symbols
	my @genes = ( 'TP53' );

	# Field configuration - see documentation for complete list & parameters
	my @fields = (
		{ Name =>	'Summaries' }
	);

	# Execute query
	my $result = $api->getGenesData(\@genes, \@fields);

	# Result OK? If not, die with error
	if ($result->{Result} eq JSON::false) {
		die("ERROR: $result->{Message}");
	}

	# Print the first summary text for the TP53 gene
	print $result->{Data}{TP53}{Summaries}[0]{Value};

=head2 FIELDS

Below is the list of fields that may be requested for the gene set using the API:

	Aliases
	Compounds
	Disorders
	Domains
	ExternalIdentifiers
	Genomics
	Interactions
	MolecularFunctions
	MolecularFunctionDescriptions
	Orthologs
	Paralogs
	Pathways
	Phenotypes
	Proteins
	Publications
	Summaries
	Transcripts
	Variants

=head2 SOURCES

Below is a list of all sources that provide information for (and can be used as filters for) the GeneCards API:

	AceView
	Blocks
	CST
	Copenhagen
	dbSNP
	DOTS
	EntrezGene
	Ensembl
	GenAtlas
	GeneGo
	GenomeRNAi
	GO
	HGNC
	HomoloGene
	KEGG
	PanEnsembl
	I2D
	InterPro
	MalaCards
	MaxQB
	MGI
	MINT
	NovoSeek
	OMIM
	PharmGKB
	Reactome
	RefSeq
	RDSystems
	SIMAP
	STRING
	Swiss-Prot
	Tocris
	UCSC

=head1 METHODS

=head2 new(USERNAME, API_KEY)

=over 12

=item C<USERNAME>

Your user name (email address) used to access GeneCards services.

=item C<API_KEY>

Your GeneCards API key. Contact L<support@lifemapsc.com|mailto:support@lifemapsc.com> to request an API key.

=back

=head2 getGenesData(GENES, FIELDS)

Function to request data for a set of genes.

=over 12

=item C<GENES>

An array of symbols or gene identifiers

=item C<FIELDS>

An array of fields, whereas each includes:

=over 12

=item C<Name>

Name of the field. See list of fields above.

=item C<Parameters> (Optional)

=over 12

=item C<SourceFilter>

Filter by sources - should be a list of source ShortNames. For example: ('Tocris','EntrezGene'). See list of sources above.

=item C<Limit>

Limit the number of results. Some fields are limited by default to 100 entries per field, and children to 5 (for example: supporting articles in text mined diseases).

=back

=back

=item C<RETURNS>

A hash with the Data and Result keys. In case of error, Result will be JSON::false and there will be an additional Message key with the error message.

=over 12

=item C<Data>

Includes a Hash of Gene Identifiers to Fields mapping (by name of field). 

=back

=back

=head1 COPYRIGHT

Copyright LifeMap Sciences, Inc., all rights reserved

=head1 SUPPORT

For information and support, please contact us at L<support@lifemapsc.com|mailto:support@lifemapsc.com>.

=cut

