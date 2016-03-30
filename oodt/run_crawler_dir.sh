#!/bin/bash
BINDIR=/celgene/software/apache-oodt-0.6/cas-crawler/bin

FILEPATH=$(pwd)

if [ -e cas-crawler.tar.gz ]; then
	echo "This directory has been processed before "
	exit
fi

cd $BINDIR
./crawler_launcher \
--operation \
--launchAutoCrawler \
--productPath $FILEPATH \
--filemgrUrl http://${OODT_FILEMGR_IP}:${OODT_FILEMGR_PORT} \
--clientTransferer org.apache.oodt.cas.filemgr.datatransfer.InPlaceDataTransferFactory  \
--mimeExtractorRepo ../policy/mime-extractor-map.xml \
--noRecur  \
--crawlForDirs |\
tee $FILEPATH/cas-crawler.log 


cd $FILEPATH

tar -cvvf cas-crawler.tar *.met 
gzip cas-crawler.log
gzip cas-crawler.tar
echo "Finished scanning $FILEPATH"
