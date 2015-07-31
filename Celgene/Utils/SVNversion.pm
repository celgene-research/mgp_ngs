package Celgene::Utils::SVNversion;
# simple function to convert the svn string for version in a better string



# receive a string like: $Date: 2013-05-09 12:37:50 -0700 (Thu, 09 May 2013) $ $Revision: 18 $
# and return 18 (2013-05-09)
sub version{
	my($version)=@_;
	
	$version=~/(\d{4}-\d{2}-\d{2}).+Revision: (\d+)/;
	return "[version ". $2 ." (". $1 .")]";
}

1;