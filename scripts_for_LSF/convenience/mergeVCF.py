#!/usr/bin/python
import os,re
import subprocess
import argparse
from _collections import defaultdict
import logging


logging.basicConfig(level=logging.DEBUG)
# point this script to a directory that contains the bam files to use to call peaks
vcfDirectory=None
tempDirectory=None
outputFname=None
mask=None
parser=argparse.ArgumentParser(
     description="This program is a convenience script to generate the combinations multiple vcf files."+
                 "It copies the files in a directory, makes sure that the files are tabix indexed, and then merges them ",
    epilog="Script developed by K Mavrommatis (kmavrommatis@celgene.com"+
           "Use at your own risk"
           )
parser.add_argument("-d","--directory",help="Directory that contains the vcf files. Will be traversed recursively",type=str)
parser.add_argument("-t","--temp",help="temporary directory to store files",type=str)
parser.add_argument("-o","--output",help="Output file that will store the commands to execute. This can be run using sh or bash [peak_run.sh]",type=str)
parser.add_argument("-m","--mask",help="File mask to use to select files. That will be matched to the end of the file (e.g. coord.bam)",type=str)
args=parser.parse_args()

try: args.directory
except NameError: ars.directory=None
else:
    vcfDirectory=args.directory
    logging.info("BAM directory set to " + vcfDirectory)

try: args.temp
except NameError: ars.temp=None
else:
    scriptFname=args.temp 
    logging.info("Script to call set to " + scriptFname)
try: args.output
except NameError: 
    outputFname="peakCaller"
else:
    outputFname=args.output 



try: args.mask
except NameError: 
    mask="vcf"
else:
    mask=args.mask 

logging.info("Output file set to "+ outputFname + ".sh")
logging.info("Traversing directory "+vcfDirectory)
logging.info("File mask is set to "+mask)
logging.info("Temporary directory is "+tempDirectory)

if vcfDirectory is None:
    logging.fatal( "Please provide the directory with bam files" )
    exit(1)



if outputFname is None:
    logging.fatal("Problem with output file. It is not set although it should have been")
    exit(2)
    
    
    
    



#bamDirectory="/mnt/celgene-src-bucket/DA0000096/ChIP-Seq-2/Processed/Bowtie2.human-bamfile-Mdup_1447913850_1456862015"

files=os.listdir(vcfDirectory , )
regex=re.compile( mask+'$')
regex2=re.compile(".gz$")
for f in files:
    full_path=os.path.join( vcfDirectory, f)
    full_path=full_path.replace("/mnt/","s3://")
   
    if re.search(regex, full_path ):
        # we copy the file to the temporary directory and gbzip/tabix if needed
        logging.info("Copying file "+f+" to the temporary directory")
        #copyProcess=subprocess.check_output(["aws s3 cp", full_path, "  ", tempDirectory+"/"+f] )
        if(not re.search(regex2, f)):
            logging.info("This file will be compressed.")
            #compressProcess=subprocess.check_output(["bgzip "+f] )
        logging.info("This file seems to be already compressed. Will create the tabix index")
        #indexProcess=subprocess.check_output(["tabix -p vcf "+f+".gz"] )
        
        
        
        #print full_path  +  " " + target + " " + cell_line
  
exit(0)


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
   
  
  