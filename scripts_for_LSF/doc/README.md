#NGS pipeline, setup and notes
This directory contains the pipeline for processing several NGS data types.

##INSTALLATION
In order for the pipeline to run make sure you have the following directory structure:
/celgene/software/scripts_for_LSF/   : location where the scripts are stored
/celgene/software/NGS_pipeline/:      location where home brew script are located. 


##HOW TO RUN 
before you run point the pipeline to the config file you want to use which will contain the explicit 
versions of software and databases you want to use

**export NGS_CONFIG_FILE=~/config.sh**. The default is /celgene/software/scripts_for_LSF/config/config.sh
**source /celgene/software/scripts_for_LSF/config/setEnv.sh**

The pipeline is now set. You can run the scripts in the pipeline according to the project you are analyzing.

After a pipeline task is run it stores the output (standard output in .stdout, standard error in .stderr and genera log in .log) in the log directory.
The log directory can be found by using the $NGS_LOG_DIR variable. Typically the output of a task is stored under a subdirectory structure in $NGS_LOG_DIR which contains the DA number of the project and the tool used. 

The standard s3 bucket used for processing the data can be found by using the $CELGENE_NGS_BUCKET.
 


##MAINTENANCE of the pipeline software
Currently the software that is used by the pipeline (external applications) is installed in a semi-automatic fashion using masterless puppet.
The manifests for the software are maintained by K.Mavrommatis.
The location of the manifests is git clone https://github.com/kmavrommatis/puppet.git
To install them and apply them type:
$ cd 
$ git clone https://github.com/kmavrommatis/puppet.git
$ puppet apply --parser future --modulepath ~/puppet/modules/ ~/puppet/manifests/site.pp

During the intallation software is installed, the binaries are soft linked to 
/celgene/software/bin and the explicit location of the installed binary is referenced in the file
/celgene/software/scripts_for_LSF/config/config.sh

config.sh is created by puppet as well.

A second configuration file config_sys.sh is also found in the /celgene/software/scripts_for_LSF/config/ and contains the environment of directories etc.
Although this can also be managed by a NGS_CONFIG_SYS_FILE env variable, it is recommended not to change it. THis script is also managed by puppet.

##HIDDEN GEMS
Some scripts need to know what the number of available cores is and use _all_ of them. They get this from calling the nproc command, but this runs on the head node (or more accurately on the node that submits the job)
In clusters (eg. elastic clusters) where the submission node has a different number of cores than the worker node a user my use the **$NGS_CORE_NUM** variable to set teh number of cores that each job will use. Note that this number should not exceed the number of available cores on the worker nodes otherwise the jobs will never start.


Each output directory has a numeric suffix (which is the epoch of the time of the run). If you want to change this number you can set the **$NGS_SUFFIX** variable to the number you wish. This is useful if you want to run a script and add the output in an existing directory (e.g. if you realized that one file has not been processed)

Before you run a script you can set the environment variable **$NGS_OUTPUT_DIRECTORY** to a string. This string will be added to the output directory before the numeric prefix. This is typically a string that contains the workflow step, or the tool name. 

The output of the pipeline is typically stored in a directory that is derived from the input directory by replacing SRC with Processed and at the end replacing the last directory with the analysis task name. If a user wants a different Processed directory the env variable **$NGS_PROCESSED_DIRECTORY** can be used. Note that the last directory of a filepath is removed anyway;

So overall the output directory where data is stored will be:
workDir=${workDir}/${NGS_PROCESSED_DIRECTORY}/${NGS_OUTPUT_DIRECTORY}_${NGS_SUFFIX}
where workDir comes from the directory of the input file, but Rawdata has been replaced by Processed, and the last directory is set by the script and typically indicates the step of the process.
eg. input file is:
s3://celgene-src-bucket/DA0000124/RNA-Seq/RawData/Personalis/SEM_CAN_RNA_v1.0.4_RNAseq/Deliverables/Fastq/SEM_Reads_1.fastq
in order to store the output to
s3://celgene-src-bucket/DA0000124/RNA-Seq/Processed/SEM_Reads_1.fastq.something
we need to set the NGS_PROCESSED_DIRECTORY to ../../../ (only three levels up since the last level -Fastq- will be removed anyway)

All the directories that are provided as enviroment variables will be stripped off of starting and trailing slashes

The resulting files typically have a filename that is derived from the input filename. One can change that to be derived from the display name (as it has been set in the database at the time of processing) of these files using the env variable **$NGS_STEM_DISPLAYNAME**. The resulting files will have a filename of the form _displayname_.relevantextension.
Although this makes the files more easily to comprehent, caution should be taken since the display name of a sample may change in the database.


##Help and other information

kmavrommatis@celgene.com