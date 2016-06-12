#!/usr/bin/python
import os,re
import subprocess
import argparse
from _collections import defaultdict
import logging


logging.basicConfig(level=logging.DEBUG)
# point this script to a directory that contains the bam files to use to call peaks
bamDirectory=None
scriptFname=None
outputFname=None
normal='normal'
parser=argparse.ArgumentParser(
     description="This program is a convenience script to generate the combinations of tumor normal to provide to a script."+
                 "It merely checks the database for the  condition field for each bam file and produces all combinations "+
                 "between normal and not normal files for the same cell line",
    epilog="Script developed by K Mavrommatis (kmavrommatis@celgene.com"+
           "Use at your own risk"
           )
parser.add_argument("-b","--bam",help="Directory that contains the bam files to use to call peaks",type=str)
parser.add_argument("-n","--normal",help="String to be used to recognize the normal samples [normal]",type=str)
parser.add_argument("-s","--script",help="Script with bsub job to call with the files in the bam directory",type=str)
parser.add_argument("-o","--output",help="Output file that will store the commands to execute. This can be run using sh or bash [peak_run.sh]",type=str)
args=parser.parse_args()

try: args.bam
except NameError: ars.bam=None
else:
    bamDirectory=args.bam
    logging.info("BAM directory set to " + bamDirectory)

try: args.script
except NameError: ars.script=None
else:
    scriptFname=args.script 
    logging.info("Script to call set to " + scriptFname)
try: args.output
except NameError: 
    outputFname="peakCaller"
else:
    outputFname=args.output 
try: args.normal
except NameError: 
    normal="normal"
else:
    normal=args.normal 

logging.info("Output file set to "+ outputFname + ".sh")


if bamDirectory is None:
    logging.fatal( "Please provide the directory with bam files" )
    exit(1)

if scriptFname is None:
    logging.fatal("Please provide the processing script ")
    exit(1)

if outputFname is None:
    logging.fatal("Problem with output file. It is not set although it should have been")
    exit(2)
    
    
    
    



#bamDirectory="/mnt/celgene-src-bucket/DA0000096/ChIP-Seq-2/Processed/Bowtie2.human-bamfile-Mdup_1447913850_1456862015"

tumor=defaultdict(list) # hold lists the file names for each cell_line
normalDict=defaultdict(list)
counter=0

files=os.listdir( bamDirectory , )
regex=re.compile( 'coord.bam$')
for f in files:
    full_path=os.path.join( bamDirectory, f)
    full_path=full_path.replace("/mnt/","s3://")
   
    if re.search(regex, full_path ):
        # we need to get the information abou the cell line and the antibody_target for this file
#         counter +=1
#         if counter == 4 :
#             break
        logging.info("Getting information for file "+ full_path)
        patient=subprocess.check_output(["ngs-sampleInfo.pl", full_path, "celgene_id"] )
        condition=subprocess.check_output(["ngs-sampleInfo.pl", full_path,"condition"] )
        logging.info("Sample "+full_path + " has celgene_id "+patient+" and condition "+condition )
        if condition.lower() == normal.lower() :
            normalDict[ patient ].append( full_path )
        else:
            tumor[ patient ].append( full_path ) 
        #print full_path  +  " " + target + " " + cell_line
  

tmpOutFn=outputFname + ".sh"  
targetFile=open(tmpOutFn,'w') 
for k in normalDict.keys() :
    
    logging.info("Patient is set to "+ k +"." )
    
     
    for normalFile in normalDict[ k ]: 
        for tumorFile in tumor[ k ]:
            commandLine=scriptFname + " " + normalFile + " " + tumorFile 
            logging.info( commandLine )
            targetFile.write( commandLine + "\n" ) 

targetFile.close()
   
  
  