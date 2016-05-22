package adaptors::Solr;
require XML::Simple;
require LWP::ConnCache;
require LWP::UserAgent;
require HTTP::Request::Common;
require URI::Escape;
require JSON;
use strict;
use warnings;


sub new{
    my $class = shift;
    my $self = {
    '_AUTOCOMMIT' => 0,
    '_SOLR_URL' => shift,
    '_QUERY_HEIGHLIT' => 0,
    'is_error' => 0,
    'error' => undef
    };
    if (! $self->{'_SOLR_URL'}) {
    $self->{'_SOLR_URL'} = 'http://localhost:8983/solr';
    }
    $self->{'_SOLR_POST_URL'} = $self->{'_SOLR_URL'}."/update";
    $self->{'_SOLR_SEARCH_URL'} =$self->{'_SOLR_URL'} . "/select";
   
    $self->{'_SOLR_ADMIN_URL'} = $self->{'_SOLR_URL'} ."/admin";
    $self->{'_SOLR_PING_URL'} = $self->{'_SOLR_ADMIN_URL'} . "/ping";
    $self->{'_CT_XML'} = { 'Content_Type' => 'text/xml; charset=utf-8' };
    $self->{'_CT_JSON'} = { 'Content_Type' => 'text/json'};
    $self->{connectionPool}=LWP::ConnCache->new();
    bless $self, $class;
    return $self;
}

#
# method: autocommit
#    This is method is used for setting the autocommit on or off.
# params:
#     flag: 1 or 0, 1 for setting autocommit on and 0 for off.
# return
#    always returns true
#
sub autocommit
{
    my ($self, $flag) = @_;
    $self->{_AUTOCOMMIT} = $flag | 1;
    return 1;
}

# method: add
#     This method is used for adding documents for indexing.
# It sends a xml http request.  First it will convert the raw
# datastructure to required ds then it will convert this ds to
# xml. This xml will be posted to Apache solr for indexing.
# Depending on the flag AUTOCOMMIT the documents will be indexed
# immediatly or on commit is issued.
# params:
#     Params: This parameter specifies set of list of document
#        document fileds and values.
# return
#    1 for successful posting of the xml document
#    0 for any failure
#
# Check error method for for getting the error details for last command
#
sub add
{
    my ($self, $params) = @_;
    my $ds = $self->_rawDsToSolrDs($params);
    my $doc = $self->_toXML($ds, 'add');
    
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    my $url = "$self->{_SOLR_POST_URL}?commit=" . $commit;
    my $response = $self->_request($url, 'POST', undef, $self->{_CT_XML}, $doc);

    return 1 if ($self->_parseResponse($response));
    return 0;
}

# Kostas: test to see if update can be performed
sub update
{
    my ($self, $params, $update_field) = @_;
    my $ds = $self->_rawDsToSolrDs($params);
    my $doc = $self->_toXML($ds, 'add');
    $doc=~s/"$update_field"/"$update_field" update="add"/g;
#    print "XML:\n$doc\n";
    
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
     
    my $url = "$self->{_SOLR_POST_URL}?commit=" . $commit;
#    print "URL:\n$url\n";
    my $response = $self->_request($url, 'POST', undef, $self->{_CT_XML}, $doc);

    return 1 if ($self->_parseResponse($response));
    return 0;
}

# replace is the same as update but instead of add it uses set
sub replace
{
    my ($self, $params, $update_field) = @_;
    my $ds = $self->_rawDsToSolrDs($params);
    my $doc = $self->_toXML($ds, 'add');
    $doc=~s/"$update_field"/"$update_field" update="set"/g;
#    print "XML:\n$doc\n";
    
    my $commit = $self->{_AUTOCOMMIT} ? 'true' : 'false';
    
    
    my $url = "$self->{_SOLR_POST_URL}?commit=" . $commit;
#    print "URL:\n$url\n";
    my $response = $self->_request($url, 'POST', undef, $self->{_CT_XML}, $doc);

    return 1 if ($self->_parseResponse($response));
    return 0;
}
#
# method: commit
#    This method is used for commiting the transaction that was initiated.
#     Request XML format:
#         true
# params : -
# returns :
#    1 for success
#    0 for any failure
#
# Check error method for for getting the error details for last command
#
sub commit
{
    my ($self) =  @_;
    my $url = $self->{_SOLR_POST_URL};
    my $cmd = $self->_toXML('true', 'commit');
    my $response = $self->_request($url, 'POST', undef, $self->{_CT_XML}, $cmd);

    return 1 if ($self->_parseResponse($response));
    return 0;
}


#
# method: commit
#    This method is used for issuing rollback on transaction that
# was initiated. Request XML format:
#     <rollback>
# params : -
# returns :
#    1 for success
#    0 for any failure
#
# Check error method for for getting the error details for last command
#
sub rollback
{
    my ($self) = @_;
    my $url = $self->{_SOLR_POST_URL};
    my $cmd = $self->_toXML('', 'rollback');
    my $response = $self->_request($url, 'POST', undef, $self->{_CT_XML}, $cmd);

    return 1 if ($self->_parseResponse($response));
    return 0;
}

#
# method: exists
#    This method is used for checking if the document with ID specified
# exists in solr index database or not.
# params :
#    id: document id for searching in solr dabase for existance
# returns :
#    1 for success
#    0 for any failure
#
# Check error method for for getting the error details for last command
#
sub exists
{
    my ($self, $id) = @_;
    my $url = "$self->{_SOLR_SEARCH_URL}?q=id:$id";
    my $response = $self->_request($url, 'GET');
    my $status = ($self->_parseResponse($response));
    if ($status) {
    my $xs = new XML::Simple();
    my $xmlRef;
    eval {
        $xmlRef = $xs->XMLin($response->{response});
    };
    if ($xmlRef->{lst}->{'int'}->{status}->{content} eq 0){
        if ($xmlRef->{result}->{numFound} gt 0) {
        return 1;
        }
    }
    }
    return 0;
}

#
# method: search
#    This methods is used for searching the documents in Apache solr database
# params :
#    queryParams : extra params that are used while extracting the solr
#    docs, e.g. fl: which fields needs to in output,
#           wt: solr response format (json, xml)
#           hl: hightlighting (true/false)
#                  rows: number of records to extract(used while paging
#                  default is 10);
#    query: specify the query params,
#        { q => specifies the default search field}
#       resultformat : in which format to return the result
#       skipEscape: for this params url escap is not done
#
# returns :
#    response from apache solr in format specified in $resultformat argument
#    if no resultformat is specified default is 'xml' for success
#
#     undef for failure   
#
# Check error method for for getting the error details for last command
#
sub search
{
    my ($self, $queryParams, $query, $resultformat, $skipEscape)  = @_;
    $skipEscape = {} unless $skipEscape;

    # If output format is not passed set it to XML
    $resultformat = "xml" unless $resultformat;
    my $DEFAULT_FIELD_CONNECTOR = "AND";

    my $url = "$self->{_SOLR_SEARCH_URL}";

    my $queryField = "";
    if (! $query) {
    $self->{is_error} = 1;
    $self->{errmsg} = "Query params not specified";
    return undef;
    }

    # Add query params to queryString
    foreach my $key (keys %$queryParams) {
    $queryField .= "$key=". URI::Escape::uri_escape($queryParams->{$key}) . "&";
    }

    # Add solr query to queryString
    my $qStr = "q=";
    if (defined $query->{q}) {
        $qStr .= URI::Escape::uri_escape($query->{q}). "&";
    } else {
    foreach my $key (keys %$query) {
        if (defined $skipEscape->{$key}) {
        $qStr .= "+$key:" . $query->{$key} ." $DEFAULT_FIELD_CONNECTOR ";
        } else {
               $qStr .= "+$key:" . URI::Escape::uri_escape($query->{$key}) .
                        " $DEFAULT_FIELD_CONNECTOR ";
        }
    }
    # Remove last occurance of ' AND '
    $qStr =~ s/ AND $//g;
    }
    $queryField .= "&$qStr";
	my $requestUrl="$url?$queryField";
#	print "Debug: $requestUrl\n";
    my $response = $self->_request($requestUrl, 'GET');
    my $responseCode = $self->_parseResponse($response, $resultformat);
    if ($responseCode) {
    if ($resultformat eq "json") {
        my $out = JSON::from_json($response->{response});
        $response->{response} = $out;
        return $response;
    }
    }
    return $response;
}

# method: ping
#    This methods is check Apache solr server is reachable or not
# params : -
# returns :
#     1 for success   
#     0 for failure
# Check error method for for getting the error details for last command
#
sub ping
{
    my ($self, $errors) = @_;
#    print "Debug: Asking ping information at $self->{_SOLR_PING_URL}\n";
    my $response = $self->_request($self->{_SOLR_PING_URL}, 'GET');

    return 1 if ($self->_parseResponse($response));
    return 0;
}

sub clear_error
{
    my ($self) = @_;
    $self->{is_error} = 0;
    $self->{error} = undef;
}

#
# method: error
#     returns the errors details that was occured during last transaction action.  
# params : -
# returns : response details includes the following details
#    {
#          url => 'url which is being accessed',
#       response => 'response from server',
#       code => 'response code',
#       errmsg => 'for any internal error error msg'
#     }
#
#
sub error
{
    my ($self) = @_;
    return $self->{error};
}

# Internal Method used for sending HTTP
# url : Requested url
# method : HTTP method
# dataType : Type of data posting (binary or text)
# headers : headers as key => value pair
# data : if binary it will as sequence of character
#          if text it will be key => value pair
sub _request
{
    my ($self, $url, $method, $dataType, $headers, $data) = @_;

    # Intialize the request params if not specified
    $dataType = ($dataType) ? $dataType : 'text';
    $method = ($method) ? $method : 'POST';
    $url = ($url) ? $url : $self->('_SOLR_URL');
    $headers = ($headers) ?  $headers : {};
    $data = ($data) ? $data: '';

    my $out = {};

    # create a HTTP request
    my $ua = LWP::UserAgent->new(keep_alive=>1);
    $ua->conn_cache( $self->{connectionPool});
    my $request = HTTP::Request->new;
    $request->method($method);
    $request->uri($url);

    # set headers
    foreach my $header (keys %$headers) {
    $request->header($header =>  $headers->{$header});
    }

    # set data for posting
    $request->content($data);

    # Send request and receive the response
    my $response = $ua->request($request);
    $out->{responsecode} = $response->code();
    $out->{response} = $response->content;
    $out->{url} = $url;
    return $out;
}

#
# Internal Method:
# method to parse solr server response
#
sub _parseResponse
{
    my ($self, $response, $responseType) = @_;

    # Clear the error fields
    $self->{is_error} = 0;
    $self->{error} = undef;
  
    $responseType = "xml" unless $responseType;

    # Check for successfull request/response
    if ($response->{responsecode} eq "200") {
           if ($responseType eq "json") {
        my $resRef = JSON::from_json($response->{response});
        if ($resRef->{responseHeader}->{status} eq 0) {
        return 1;
        }
    } else {
        my $xs = new XML::Simple();
        my $xmlRef;
        eval {
              $xmlRef = $xs->XMLin($response->{response});
            };
        if ($xmlRef->{lst}->{'int'}->{status}->{content} eq 0){
        return 1;
        }
    }
    }
    $self->{is_error} = 1;
    $self->{error} = $response;
    $self->{error}->{errmsg} = $@;
    return 0;
}

# Internal Method
# This function will convert the datastructe to XML document
#
sub _toXML
{
    my ($self, $params, $rootnode) = @_;
    my $xs = new XML::Simple();
    my $xml;
    if (! $rootnode) {
    $xml = $xs->XMLout($params);
    } else {
    $xml = $xs->XMLout($params, rootname => $rootnode);
    }
    return $xml;
}

# Convert raw DS to sorl requird DS.
# Input format :
#    [
#    {
#        attr1 => [ value1, value2],
#        attr2 => [valu3, value4]
#    },
#    ...
#    ]
# Output format:
#    [
#    { field => [ { name => attr1, content => value1 },
#             { name => attr1, content => value2 },
#             { name => attr2, content => value3 },
#             { name => attr2, content => value4 }
#            ],
#    },
#    ...
#    ]
sub _rawDsToSolrDs
{
    my ($self, $docs) = @_;
    my $ds = [];
    for my $doc (@$docs) {
    my $d = [];
    for my $field (keys %$doc) {
        my $values = $doc->{$field};
        if (ref ($values) =~/ARRAY/) {
        for my $val (@$values) {
            push @$d, {name => $field, content => $val};
        }
        } else {
        push @$d, { name => $field, content => $values};
        }
    }
    push @$ds, {field => $d};
    }
    $ds = { doc => $ds };
    return $ds;
} 

1;