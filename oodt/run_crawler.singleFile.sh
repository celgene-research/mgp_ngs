#!/bin/bash
file=$1
if [ -z "$1" ]; then
echo "Please provide a single file to ingest"
exit
fi


BINDIR=/celgene/software/apache-oodt-0.6/cas-crawler/bin

FILEPATH=$(pwd)

if [ -e cas-crawler.tar.gz ]; then
	echo "This directory has been processed before "
	exit
fi
mkdir -p ${NGS_TMP_DIR}/crawler_$$

echo "Using temporary directory ${NGS_TMP_DIR}/crawler_$$"
rsync -avq $file ${NGS_TMP_DIR}/crawler_$$/$(basename $file)
rsync -avq  ${file}.met ${NGS_TMP_DIR}/crawler_$$/$(basename $file).met
#ln -s $directory ${NGS_TMP_DIR}/crawler_$$/$(basename $directory)
#ln -s ${directory}.met ${NGS_TMP_DIR}/crawler_$$/$(basename $directory).met


cd ${NGS_TMP_DIR}/crawler_$$
chmod -R 644 *
${BINDIR}/run_crawler.sh
updateSOLR.pl --recursive ${NGS_TMP_DIR}/crawler_$$/$(basename $file) $file
tar -cvvf cas-crawler.tar *.met 
gzip cas-crawler.log
gzip cas-crawler.tar
#rm -rf ${NGS_TMP_DIR}/crawler_$$/

cd $FILEPATH


echo "Finished scanning $FILEPATH"
