#!/bin/bash
directory=$1
if [ -z "$1" ]; then
echo "Please provide a single directory to ingest"
exit
fi

lastchar="${directory: -1}"
if [ "$lastchar" == "/" ] ; then
	directory=${directory:0:${#directory}-1}
fi

BINDIR=/celgene/software/apache-oodt-0.6/bin

FILEPATH=$(pwd)

if [ -e cas-crawler.tar.gz ]; then
	echo "This directory has been processed before "
	exit
fi
mkdir -p ${NGS_TMP_DIR}/crawler_$$

echo "Using temporary directory ${NGS_TMP_DIR}/crawler_$$"
rsync -avq --recursive $directory ${NGS_TMP_DIR}/crawler_$$/$(basename $directory)
rsync -avq --recursive ${directory}.met ${NGS_TMP_DIR}/crawler_$$/$(basename $directory).met
#ln -s $directory ${NGS_TMP_DIR}/crawler_$$/$(basename $directory)
#ln -s ${directory}.met ${NGS_TMP_DIR}/crawler_$$/$(basename $directory).met


cd ${NGS_TMP_DIR}/crawler_$$
${BINDIR}/run_crawler_dir.sh
updateSOLR.pl --recursive ${NGS_TMP_DIR}/crawler_$$/$(basename $directory) $directory
tar -cvvf cas-crawler.tar *.met 
gzip cas-crawler.log
gzip cas-crawler.tar
#rm -rf ${NGS_TMP_DIR}/crawler_$$/

cd $FILEPATH


echo "Finished scanning $FILEPATH"
