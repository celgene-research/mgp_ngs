package analysisTaskInfo;
# package to handle analysis task related information

use strict;
use warnings;

my $logger=Log::Log4perl->get_logger("sampleInfo");


# create a new task and return the id of it
# the status of the process is set to 'registered'
# a subsequent call will turn the status to 'In progress'
sub createNewTask{
	my($taskName)=@_;
	
	my $sql=qq{
		insert into analysis_task
		(task_type,analysis_task_status)values('$taskName',4)
	};
	my $dbh=DatabaseFunc::connectDB();
	$logger->debug("createNewTask:  Runing sql $sql");
	$dbh->do( $sql );
	
	
	my $task_id=$dbh->last_insert_id( undef,undef,"analysis_task","analysis_task_id");
	$dbh->disconnect();
	$logger->info("After executing $sql I got back $task_id");
	return($task_id);
}

# update the status of a task
sub updateTask{
	my($task_id,$newStatus)=@_;
	
	my $sql=qq{
		update analysis_task
		set analysis_task_status=$newStatus
		where analysis_task_id=$task_id
	};
	my $dbh=DatabaseFunc::connectDB();
	$dbh->do( $sql );
	$dbh->disconnect();
}

1;