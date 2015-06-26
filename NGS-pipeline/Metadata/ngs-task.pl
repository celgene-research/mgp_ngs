#!/usr/bin/perl -w
# quick script to create or update a task on the server.
use strict;
use Frontier::Client;
use Data::Dumper;
my($taskName,$status)=@ARGV;

if(!defined($taskName)){
	die " $0 <task name>.  \n will return the numeric id of a new task\n";
}
my $server_url = "http://".$ENV{NGS_SERVER_IP}.":".$ENV{NGS_SERVER_PORT}."/RPC2";
my $server = Frontier::Client->new('url' => $server_url);
my ($gene)=@ARGV;

if(!defined($status)){ #create a new task
	my $result = $server->call('analysisTaskInfo.createNewTask',$taskName);
	print $result  ."\n";
}else{ #update existing
	$server->call('analysisTaskInfo.updateTask', $taskName, $status);
}

exit(0);
