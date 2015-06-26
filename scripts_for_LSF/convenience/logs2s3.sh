project=$1

hosts=$(bhosts | wc -l)
hosts=$(( $hosts -1 ))

for i in `seq 1 $hosts`;do
	bsub -x 's3cmd sync /celgene/LOGS/ s3://celgene-ngs-data/Processed/${project}/LOGS/; sleep 20'
done