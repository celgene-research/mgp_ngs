#!/bin/bash

# use this script to copy the logs to the celgene bucket of the corresponding project
if [ -z "${CELGENE_AWS}" ]; then 
	echo "Run this script from an AWS instance only "
	exit
fi
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh


for directory in `ls $NGS_LOG_DIR`; do
	directory=${NGS_LOG_DIR}/${directory}/
	da=$( getDataAssets ${directory} )
	if [ -z "$da" ]; then
		echo "The directory $directory does not belong to a DA"
	else
		logs=$NGS_LOG_DIR/${da}/
		target=${CELGENE_NGS_BUCKET}/${da}/LOGS/
		echo "Syncing $logs to $target"	
		s3cmd sync  ${logs} ${target}	
	fi

done