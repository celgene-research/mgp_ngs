hosts=$(bhosts | wc -l)
hosts=$(( $hosts -1 ))


for i in `seq 1 $hosts`; do
	bsub -x 'rm -rf /celgene/LOGS/*; rm -rf /scratch/*; sleep 20'
done
			