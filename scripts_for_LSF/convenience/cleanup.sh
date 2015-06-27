hosts=$(bhosts | wc -l)
hosts=$(( $hosts -1 ))


for i in `seq 1 $hosts`; do
	bsub -x 'rm -rf /celgene/LOGS/*; rm -rf /scratch/*; rm -rf /tmp/*; rm -rf ~/core.*;  sleep 20'
done
			
