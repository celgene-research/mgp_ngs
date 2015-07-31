package Celgene::Utils::ArrayFunc;     #  -*- perl -*-
use strict;
use warnings;
use Log::Log4perl;

my $logger=Log::Log4perl->get_logger("ArrayFunc");
# routine that finds the unique elements in an array
# use: unique(\@array,\$size_of_row);

sub unique
{
	my ($array,$size)=@_;
	if(!defined($array) ){return ();}
	if(!defined($size) or $size==0){$size=1;}
	
	my @a1=@$array;
	
	if(scalar(@$array)==1){return wantarray ? @$array:$array;}
	
	my $un_sep="UN~:~SEP";
        my %check=();
        my @uniq=();
		if ($size >1)
		{
			for(my $i=0;$i<scalar(@a1);$i++)
			{
				my $string;
				for(my $j=0;$j<$size;$j++) {$string.=$a1[$i][$j].$un_sep;}
				unless($check{$string})
				{
					my @temp_array=split($un_sep,$string);
					push @uniq,[@temp_array];
					$check{$string}=1;
				}
			}
		}
		elsif ($size==1)
		{
			foreach my $e(@a1)
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
		}
        return wantarray ? @uniq : \@uniq;
}

# routine that finds the intersection between two arrays
#use: intersect(\@array1,\@array2);
# returns an array with the common elements
sub intersect
{
        my ($v1,$v2)=@_;
        
        if(!defined($v1)){
        	$logger->logdie("ArrayFunc: the first array is empty");
        }
        if(!defined($v2)){
        	$logger->logdie("ArrayFunc: the second array is empty");
        }
        
		if(scalar(@$v1)==1 and scalar(@$v2)==1){
			if($v1->[0] eq $v2->[0]){
				return wantarray ? @$v1 : $v1;
			}
		} 
			
	
        my @a1=unique($v1,1);
        my @b1=unique($v2,1);
        my @union = my @isect = ();
        my %union = my %isect = ();
	
	if( scalar(@a1)==0 or scalar(@b1)==0){
		return @isect;
	}
	
        foreach my $e (@a1)
        {
                $union{$e} = 1
        }

        foreach my $e (@b1)
        {
                if ( $union{$e} ) { $isect{$e} = 1 }
                $union{$e} = 1;
        }
        @union = keys %union;
        @isect = keys %isect;

        return wantarray ? @isect : \@isect;
}
#intersection of multidimensional arrays;
sub intersect_multi
{
    my ($a1,$b1,$dim,$verbose)=@_;
    if(!defined($verbose)){$verbose='off';}
	
    my @union = my @isect = ();
    my %union = my %isect = ();
	
	if(scalar(@$a1)==0 or scalar(@$b1)==0){
		return @isect;
	}
	
        foreach my $e (@$a1)
        {
                $union{$e->[$dim]} = 1
        }

        foreach my $e (@$b1)
        {
                if ( $union{$e->[$dim]} ) { 
                	push @isect, $e; 
                }
        }

        return wantarray ? @isect : \@isect;
}
# routine that finds the union between two arrays
#use: union(\@array1,\@array2);
# returns an array with the union of elements
sub union
{
        my $v1=$_[0];
        my $v2=$_[1];
        my @a1=@$v1;
        my @b1=@$v2;
#       print "INTER1: @a1\nINTER2: @b1\n";
        my @union = my @isect = ();
        my %union = my %isect = ();
#       %count = ();
        foreach my $e (@a1)
        {
                $union{$e} = 1
        }

        foreach my $e (@b1)
        {
                if ( $union{$e} ) { $isect{$e} = 1 }
                $union{$e} = 1;
        }
        @union = keys %union;
        @isect = keys %isect;
#       print "INTER3:@isect\n";
        return wantarray ? @union : \@union;
}

#function that finds the unique elements in two arrays
# variable $idx defines the column of the array that will be used for comparison if the array has more than one
# variable $size determines the number of rows for the array
# if not defined it means that the array is one dimensional
# returns two arrays. 
# the first is the unique elements of the first input array
# the second is the unique elements of the second input array

sub unq_elements
{
	my ($v1,$v2,$idx,$size)=@_;
	my @a1=@$v1;
	my @b1=@$v2;
	my @r1=my @r2=();
	my %r1=my %r2=();
	my @r3;
	
	
	for (my $i=0;$i<scalar(@a1);$i++)
        {
		my $e;
		if (!defined($idx)){$e=$a1[$i];}
		else {$e=$a1[$i][$idx]; }
                $r1{$e} = 1;
        }	
	for (my $i=0;$i<scalar(@b1);$i++)
        {
		my $e;
		if (!defined($idx)){$e=$b1[$i];}
		else {$e=$b1[$i][$idx];}
		$r2{$e}=1;
                if ( defined($r1{$e}) )
		{ 
			$r2{$e}=2;	
			$r1{$e}=2;
		}
        }
	
	for (my $i=0;$i<scalar(@a1);$i++)
        {
		my $e;
		if (!defined($idx))
		{
			$e=$a1[$i];
			if($r1{$e} == 1)
			{
				push @r1,$e;
			}
		}
		else 
		{
			$e=$a1[$i][$idx]; 
			if($r1{$e} == 1)
			{
				my @t;
				for(my $k=0;$k<$size;$k++)
				{
					push @t,$a1[$i][$k];
				}
				push @r1,[@t];
			}
		}
	}
	for (my $i=0;$i<scalar(@b1);$i++)
        {
		my $e;
		if (!defined($idx))
		{
			$e=$b1[$i];
			if($r2{$e} == 1)
			{
				push @r2,$e;
			}
		}
		else 
		{
			$e=$b1[$i][$idx]; 
			if($r2{$e} == 1)
			{
				my @t;
				for(my $k=0;$k<$size;$k++)
				{
					push @t,$b1[$i][$k];
				}
				push @r2,[@t];
			}
		}
	}
	
	return(\@r1,\@r2);
}


sub in
{
        my ($v1,$element,$verbose)=@_;
	if(!defined($verbose)){$verbose=1;} # by default complain if needed
	my $return_value=-1;
	if (!defined($v1)){
		die "in: pointer to array not defined\n" if $verbose ==1;
		return $return_value;
	}
	if (!defined($element)){
		die "in: element not defined\n" if $verbose ==1;
		return $return_value;
	}
        my @array=@$v1;#my $element=$$v2;
	
	
	
        for (my $i=0;$i<scalar(@array);$i++)
        {
                if ($array[$i] eq $element)
                {
                        $return_value=$i;
                        last;
                }
        }
        return $return_value;
}

sub in_multi
{
    my ($v1,$element,$dim,$verbose)=@_;
	if(!defined($verbose)){$verbose=1;} # by default complain if needed
	my $return_value=-1;
	if (!defined($v1)){
		die "in: pointer to array not defined\n" if $verbose ==1;
		return $return_value;
	}
	if (!defined($element)){
		die "in: element not defined\n" if $verbose ==1;
		return $return_value;
	}
        my @array=@$v1;#my $element=$$v2;
        for (my $i=0;$i<scalar(@array);$i++)
        {
                if ($array[$i][$dim] eq $element)
                {
                        $return_value=$i;
                        last;
                }
        }
        return $return_value;
}

# checks if a value is included in an array







# return the minimum value of an array
sub min{
	my ($ar_ref)=@_;
	my $min=${$ar_ref}[0];
	for(my $i=1;$i<scalar(@{$ar_ref});$i++){
		if (${$ar_ref}[$i]<$min){$min=${$ar_ref}[$i];}
	}
	return $min;
}
# return the maximum of an array
sub max{
        my ($ar_ref)=@_;
	my $max=${$ar_ref}[0];
	for(my $i=1;$i<scalar(@{$ar_ref});$i++){
	        if (${$ar_ref}[$i]>$max){$max=${$ar_ref}[$i];}
	}
	return $max;
}


# return the number of common elements between two arrays
# unlike intersection, the elements must be in the same order
# in the two arrays
sub arraySimilarity{
	my ($array1, $array2)=@_;

	#index the first array in a hash
	my %array1;
	for(my $i=0;$i<scalar(@$array1);$i++){
		$array1{$array1->[$i]} = $i;	
	}

	# now go through the second array and fill its hash
	# with the indeces of the first array
	my @array2_idx;
	for(my $i=0;$i<scalar(@$array2);$i++){
		if( $array1{ $array2->[$i] } ){
			push @array2_idx, $array1{ $array2->[$i] };
		}
	}
	# now  count how many elements in the array2_idx have right order of index
	my $common=0;
	for(my $a=0;$a<scalar(@array2_idx)-1;$a++){
		if($array2_idx[$a] < $array2_idx[$a+1]){
		#	print "$array2_idx[$a] - $array2_idx[$a+1]\n";
			$common ++;
		}

	}
	return $common;
}

1;
