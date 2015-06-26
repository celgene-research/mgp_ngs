#!/bin/bash
# basic script to configure the environment for the NGS toolkit
# it defines basic variables (server IPS and ports and root folder locations)
# and sources additional files

#$Date: 2015-05-22 12:22:28 -0700 (Fri, 22 May 2015) $ $Revision: 1472 $ by $Author: kmavrommatis $



# source file to have access to cluster setup
# need to have the correct switch in the bashrc 
# MEDUSSA will point to the Medussa cluster
# NEWCLUSTER will poin to the new cluster
# AWS will point to the AWS environment

# this script sets the environment variables used by the NGS pipeline
# and pointers to files and applications
# at the end it sources the file config_currrent.sh which is in the 
# same directory as this script
# or any other config file that is pointed to by the env variable $NGS_CONFIG_FILE




#############################
#############################

# NGS SERVER SETTINGS 
export NGS_SERVER_PORT=8082
export NGS_SERVER_IP=10.130.0.26
export OODT_FILEMGR_PORT=9000
export OODT_FILEMGR_IP=10.130.0.26
export SOLR_SERVER_IP=10.130.0.26
export SOLR_SERVER_PORT=8983
export OODT_FILEMGR_URL=http://${OODT_FILEMGR_IP}:${OODT_FILEMGR_PORT}
export NGS_SERVER_URL=http://${NGS_SERVER_IP}:${NGS_SERVER_PORT}

##############################
# Settings specific for each environment
# each environment (HPC/AWS) is expected to have a /celgene directory
##########################
export NGS_BASE_DIR=/celgene/
export NGS_APPLICATION_DIR=$NGS_BASE_DIR/software
export NGS_BINARIES_DIR=$NGS_BASE_DIR/software/bin
export NGS_LOG_DIR=$NGS_BASE_DIR/scratch/RED/LOGS/${USER}
export NGS_USR_DATA_DIR=$NGS_BASE_DIR/reference
export genomeDatabase=$NGS_USR_DATA_DIR/genomes
export NGS_TMP_DIR=/celgene/scratch/RED/tmp/${USER}
export JAVA_HOME=/celgene/software/java/latest/

###############################
# settings specific to AWS
if [ "$CELGENE_AWS" == "true" ]; then
	export CELGENE_NGS_BUCKET=s3://celgene-ngs-data

	export NGS_LOG_DIR=/celgene/LOGS/
	if [ -d /scratch ];then
		export NGS_TMP_DIR=/scratch
	else
		export NGS_TMP_DIR=/celgene/tmp
	fi
	export JAVA_HOME=/usr/
fi
###############################

mkdir -p $NGS_TMP_DIR
export _JAVA_OPTIONS=-Djava.io.tmpdir=${NGS_TMP_DIR}
	


	

#######
# source config file with binaries
DEFAULT_CONFIG=/celgene/software/NGS-pipeline/config.sh
if [ -z $NGS_CONFIG_FILE ] ;then
	NGS_CONFIG_FILE=$DEFAULT_CONFIG
fi
source ${NGS_CONFIG_FILE}
###############################
# variables dependent on previous settings
# and additional sourced files

# set the PATH
	export PATH=$NGS_BINARIES_DIR:$PATH
 # Paths for interpreters
	export PERL5LIB=""
	export PERL5LIB=$PERL5LIB:$NGS_APPLICATION_DIR
	export PERL5LIB=$PERL5LIB:$NGS_APPLICATION_DIR/perl/lib/perl5/
	export PERL5LIB=$PERL5LIB:$NGS_APPLICATION_DIR/perl/lib64/perl5/
	export PERL5LIB=$PERL5LIB:$NGS_APPLICATION_DIR/perl/share/perl5/
	export PERL5LIB=$PERL5LIB:$NGS_APPLICATION_DIR/vcftools/DEFAULT/lib/perl5/site_perl/
	
	export PYTHONPATH=""
	export PYTHONPATH=$PYTHONPATH:$NGS_PYTHONPATH