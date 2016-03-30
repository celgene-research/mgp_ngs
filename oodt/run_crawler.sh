#!/bin/bash
BINDIR=/celgene/software/apache-oodt-0.6/cas-crawler/bin
CURRDATE=$( date +"%m-%d-%y")
FILEPATH=$(pwd)
filesOrDirs=$1


if [ -e cas-crawler-${CURRDATE}.tar.gz ]; then
	echo "This directory has been processed before. Remove cas-crawler-${CURRDATE}.tar.gz to proceed."
	exit
fi

cd $BINDIR

if [ -n "$filesOrDirs" ]; then
echo "Ingesting directories"
./crawler_launcher \
--operation \
--launchAutoCrawler \
--productPath $FILEPATH \
--filemgrUrl $OODT_FILEMGR_URL \
--clientTransferer org.apache.oodt.cas.filemgr.datatransfer.InPlaceDataTransferFactory \
--mimeExtractorRepo ../policy/mime-extractor-map.xml \
--noRecur \
--crawlForDirs 2>&1 |\
tee $FILEPATH/cas-crawler-${CURRDATE}.log 
else
./crawler_launcher \
--operation \
--launchAutoCrawler \
--productPath $FILEPATH \
--filemgrUrl $OODT_FILEMGR_URL \
--clientTransferer org.apache.oodt.cas.filemgr.datatransfer.InPlaceDataTransferFactory  \
--mimeExtractorRepo ../policy/mime-extractor-map.xml \
--noRecur 2>&1 |\
tee $FILEPATH/cas-crawler-${CURRDATE}.log
fi

cd $FILEPATH


tar -cvvzf cas-crawler-${CURRDATE}.tar.gz *.met 
gzip cas-crawler-${CURRDATE}.log
#rm *.met
echo "Finished scanning $FILEPATH"
