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
    logging.info("VCF directory set to " + vcfDirectory)

try: args.temp
except NameError: args.temp=None
else:
    tempDirectory=args.temp 
    logging.info("Temporary directory set to " + tempDirectory)
try: args.output
except NameError: 
    outputFname="mergevcf"
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
    
    
    
    

try:
    logging.info("Creating temporary directory")
    os.makedirs(tempDirectory)
except OSError as exception:
    logging.info("The temporary directory already exists")

#bamDirectory="/mnt/celgene-src-bucket/DA0000096/ChIP-Seq-2/Processed/Bowtie2.human-bamfile-Mdup_1447913850_1456862015"

regex=re.compile( mask+'$')
regex2=re.compile(".gz$")
fileList=''
infoList=''
for root,dirs,files in os.walk(vcfDirectory , ):
    for f in files :
        #print root+","+f
        full_path=os.path.join( vcfDirectory, f)
        
        full_path=full_path.replace("/mnt/","s3://")
        
        if re.search(regex, f):
            # we copy the file to the temporary directory and gbzip/tabix if needed
            copyCommand="aws s3 cp  "+ full_path+ "  "+ tempDirectory+f
            logging.info("Copying file "+f+" to the temporary directory."+copyCommand)
           
            #copyProcess=subprocess.call(copyCommand, shell=True )
            if(not re.search(regex2, f)):
                compressCommand="bgzip "+tempDirectory+f
                logging.info("This file will be compressed with ."+compressCommand)
                #compressProcess=subprocess.check_output(compressCommand ,shell=True )
            indexCommand="tabix -p vcf "+tempDirectory+f+".gz"
            logging.info("Creating the tabix index. "+indexCommand)
            #indexProcess=subprocess.check_output(indexCommand,shell=True)
            
            getMetadataCommand="ngs-sampleInfo.pl "+full_path+" display_name"
            logging.info("Getting the display name(s) for the file." +getMetadataCommand)
            getMetadataProcess=subprocess.check_output( getMetadataCommand,shell=True)
            display_name=getMetadataProcess.split(" ")[0]
            
            # get the header from the vcf.tgz file
            # and parse the last line 
            headerCommand="tabix -H "+tempDirectory+f+".gz"
            header=subprocess.check_output( headerCommand, shell=True)
            for line in header.splitlines(True):
                if re.search( "CHROM",line):
                    tokens=line.split("\t")
                    # for vcf files with one sample we use as sample name the display name
                    # for vcf files with two samples (tumor/normal) we use the display_name  and the existing name in the file
                    if len(tokens)==10:
                        tokens[10]=display_name
                    if len(tokens)==11:
                        for i in range(9 , len( tokens )) :
                            tokens[ i ]=display_name + "."+tokens[i].replace( display_name, "")
                        
                    print "info "+  str.join("\t", tokens[ 9:len(tokens)])
            fileList=fileList + f
            infoList=infoList + str.join("\t", tokens[ 9:len(tokens)])
            #print full_path  +  " " + target + " " + cell_line
 
 
print  fileList
print infoList      
exit(0)


tmpOutFn=outputFname + ".sh"  
targetFile=open(tmpOutFn,'w')
# run vcf-merge on a per chromosome basis
parallel=" \
analyze() { \
vcf-merge -r $1 filelist > "+tempDirectory+" $1.vcf \
} \
export -f analyze "

mergeCommand="parallel  -j$(nproc) analyze chr{} :::  {1..22} X Y "

concatCommand="bcftools concat "+tempDirectory+"chr{{1..22},{X,Y}}.vcf -O z -o "+tempDirectory+"/merged.vcf"

targetFile.write(parallel)
targetFile.write(mergeCommand)
targetFile.write(concatCommand)
 

targetFile.close()
   
  
  