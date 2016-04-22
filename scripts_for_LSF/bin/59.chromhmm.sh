#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh


cores=$( fullcores )
# use this script to prepare and run files that were procesed by MACS or bam files
processType='bam' #='macs'

# use this sscript to call ChromHMM on peak files that have been produced by MACS
# what is the location of the files?
# all files with peaks called by MACS should be under this directory and should have the extension xls
#peaksDirectory=$1
peaksDirectory="/home/kmavrommatis/celgene-src-bucket/DA0000096/ChIP-Seq-2/Processed/MACS2-peaks_1449703420/"
bamDirectory="/home/kmavrommatis/celgene-src-bucket/DA0000096/ChIP-Seq-2/Processed/Bowtie2.human-bamfiles_1447913850"
step="ChromHMM"
analysistask=$step
if [ "$processType" == "bam" ] ; then
inDirectory=$bamDirectory
else
inDirectory=$peaksDirectory
fi



# first work with the peaks file
stem=$(fileStem $peaksDirectory )
initiateJob $stem $step $peaksDirectory


#initiateJob $stem $step $peaksDirectory
outputDirectory=$( setOutput $(stage.pl --type directory --name $peaksDirectory)  ${step} )

# Prepare the cellmarkfiletable <cell type>	<mark>	<name of bed file>	<control file[optional]>
if [ -e cellmarkfiletable.peaks ]; then 
	rm cellmarkfiletable.peaks
fi
if [ -e cellmarkfiletable.bam ]; then 
	rm cellmarkfiletable.bam
fi


#for i in \
# `aws s3 ls $inDirectory --recursive | grep broadPeak$| rev| cut -f1 -d ' '| rev` \
# `aws s3 ls $inDirectory --recursive | grep narrowPeak$| rev| cut -f1 -d ' '| rev` \
# `aws s3 ls $inDirectory --recursive | grep coord.bam$| rev| cut -f1 -d ' '| rev`

for i in \
`find $peaksDirectory  | grep broadPeak$` \
`find $peaksDirectory  | grep narrowPeak$` 
do  
	f=$(echo ${i} | sed 's|/home/kmavrommatis/|s3://|'); 
	#echo $f; 
	
	cell_type=$( ngs-sampleInfo.pl ${f} display_name | cut -f1 -d ' ')
	mark=$( ngs-sampleInfo.pl ${f} antibody_target | cut -f1 -d ' ' )
	#s3cmd get --force $f $(basename $f)	
	ln -s $i $( basename $i )
echo "${cell_type}	${mark}	"$(basename $i)  >> cellmarkfiletable.peaks
done 

for i in \
`find $bamDirectory  | grep coord.bam$` 
do  
	f=$(echo ${i} | sed 's|/home/kmavrommatis/|s3://|'); 
	#echo $f; 
	
	cell_type=$( ngs-sampleInfo.pl ${f} display_name | cut -f1 -d ' ')
	mark=$( ngs-sampleInfo.pl ${f} antibody_target | cut -f1 -d ' ' )
	ln -s $i $( basename $i )
	#s3cmd get --force $f $(basename $f)	
echo "${cell_type}	${mark}	"$(basename $i)  >> cellmarkfiletable.bam
done 
grep -v Input cellmarkfiletable.bam  | sort -k1,2> marks.txt
grep  Input cellmarkfiletable.bam  | sort -k1,2> input.txt  
join -t '	' -o 1.1 1.2 1.3 2.3 marks.txt input.txt > cellmarkfiletable.bam
rm marks.txt input.txt


for i in `find $peaksDirectory | grep chromInfo`
do 
		
	f=$(echo ${i} | sed 's|/home/kmavrommatis/|s3://|'); 
	s3cmd get --force $f 	
	break
done 

exit

models=5

celgeneExec.pl --analysistask ${analysistask} "\
java -Xmx4000M \
-jar $chromhmmbin BinarizeBed \
-b 200  -peaks \
chromInfo.txt $peaksDirectory cellmarkfiletable $PWD $outputDirectory/BinarizeBed ; \
java -Xmx4g \
-jar $chromhmmbin LearnModel \
-b 200 -l chromInfo.txt -p $cores \
$outputDirectory/BinarizeBed $outputDirectory/Model.Bed_${models} $models hg19 ; \
"


celgeneExec.pl --analysistask ${analysistask} "\
java -Xmx4000M \
-jar $chromhmmbin BinarizeBam \
-b 200  \
chromInfo.txt $PWD cellmarkfiletable $PWD $outputDirectory/BinarizeBam ; \
java -Xmx4g \
-jar $chromhmmbin LearnModel \
-b 200 -l chromInfo.txt -p $cores \
$outputDirectory/BinarizeBed $outputDirectory/Model.Bam_${models} $models hg19 ; \
"

