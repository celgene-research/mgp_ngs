#!/bin/bash
# basic script to configure the environment for the NGS toolkit
# it defines basic variables (server IPS and ports and root folder locations)
# and sources additional files

#$Date: 2015-10-16 16:57:09 -0700 (Fri, 16 Oct 2015) $ $Revision: 1724 $ by $Author: kmavrommatis $



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

# default NGS SERVER SETTINGS 







###############################
# settings specific to AWS
if [ "$CELGENE_AWS" == "true" -o "$FACTER_ENV" == "RCE" ]; then
	export NGS_SERVER_PORT=8082
	export NGS_SERVER_IP=10.130.0.26
	export OODT_FILEMGR_PORT=9000
	export OODT_FILEMGR_IP=10.130.0.26
	export SOLR_SERVER_IP=10.130.0.26
	export SOLR_SERVER_PORT=8983
	export CELGENE_NGS_BUCKET=s3://celgene-src-bucket

	export NGS_LOG_DIR=/celgene/software/LOGS/
	if [ -d /scratch ];then
		export NGS_TMP_DIR=/scratch/tmp/${USER}
	else
		export NGS_TMP_DIR=/celgene/tmp/${USER}
	fi
	export JAVA_HOME=/usr/
elif [ "$MMGP_AWS" == "true" -o "$FACTER_ENV" == "MMGP" ] ; then
	export NGS_SERVER_PORT=8082
	export NGS_SERVER_IP=192.168.8.44
	export OODT_FILEMGR_PORT=9000
	export OODT_FILEMGR_IP=192.168.8.44
	export SOLR_SERVER_IP=192.168.8.44
	export SOLR_SERVER_PORT=8983	
	export CELGENE_NGS_BUCKET=s3://celgene.rnd.combio.mmgp.external

	export NGS_LOG_DIR=/celgene/software/LOGS-${USER}/
	if [ -d /scratch ];then
		export NGS_TMP_DIR=/scratch/tmp/${USER}
	else
		export NGS_TMP_DIR=/celgene/tmp/${USER}
	fi
	
	export JAVA_HOME=/usr/
else
	export NGS_SERVER_PORT=8082
	export NGS_SERVER_IP=10.130.0.26
	export OODT_FILEMGR_PORT=9000
	export OODT_FILEMGR_IP=10.130.0.26
	export SOLR_SERVER_IP=10.130.0.26
	export SOLR_SERVER_PORT=8983
	export JAVA_HOME=/celgene/software/java/latest/
	export NGS_TMP_DIR=/celgene/scratch/RED/tmp/${USER}
	export NGS_LOG_DIR=$NGS_BASE_DIR/scratch/RED/LOGS-${USER}
fi
###############################

##############################
# Settings specific for each environment
# each environment (HPC/AWS) is expected to have a /celgene directory
##########################
export NGS_BASE_DIR=/celgene/
export NGS_APPLICATION_DIR=$NGS_BASE_DIR/software
export NGS_LSF_SCRIPTS=${NGS_APPLICATION_DIR}/scripts_for_LSF
export NGS_BINARIES_DIR=$NGS_BASE_DIR/software/bin

export NGS_USR_DATA_DIR=$NGS_BASE_DIR/reference
export genomeDatabase=$NGS_USR_DATA_DIR/genomes


export OODT_FILEMGR_URL=http://${OODT_FILEMGR_IP}:${OODT_FILEMGR_PORT}
# the NGS_SERVER_URL became a SSL based  (has to wait until this connection is enabled)
export NGS_SERVER_URL=http://${NGS_SERVER_IP}:${NGS_SERVER_PORT}

mkdir -p $NGS_TMP_DIR
export TMPDIR=$NGS_TMP_DIR
mkdir -p $TMPDIR
chmod 1777 $TMPDIR 2>/dev/null
 
export _JAVA_OPTIONS=-Djava.io.tmpdir=${NGS_TMP_DIR}
	


	

#######
# source config file with binaries
DEFAULT_CONFIG=${NGS_LSF_SCRIPTS}/config/config.sh
DEFAULT_CONFIG_SYS=${NGS_LSF_SCRIPTS}/config/config_sys.sh
if [ -z $NGS_CONFIG_FILE ] ;then
	NGS_CONFIG_FILE=$DEFAULT_CONFIG
fi
if [ -z $NGS_CONFIG_SYS_FILE ] ;then
	NGS_CONFIG_SYS_FILE=$DEFAULT_CONFIG_SYS
fi
source ${NGS_CONFIG_SYS_FILE}
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
	export PERL5LIB=$PERL5LIB:$NGS_PERL5LIB
	
	export PYTHONPATH=""
	export PYTHONPATH=$PYTHONPATH:$NGS_PYTHONPATH
