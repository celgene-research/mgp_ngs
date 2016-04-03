#!/bin/bash
BINDIR=/celgene/software/apache-oodt/crawler/bin
CURRDATE=$( date +"%m-%d-%y")
FILEPATH=$(pwd)
filesOrDirs=$1
TEMPLOG=$NGS_LOG_DIR/crawler-${CURRDATE}.log
echo "Processing $FILEPATH "> $TEMPLOG
echo "Data       $CURRDATE" >> $TEMPLOG

if [ -e $TEMPLOG ]; then
	echo "This directory has been processed before. Remove $TEMPLOG to proceed."
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
tee -a $TEMPLOG 
else
./crawler_launcher \
--operation \
--launchAutoCrawler \
--productPath $FILEPATH \
--filemgrUrl $OODT_FILEMGR_URL \
--clientTransferer org.apache.oodt.cas.filemgr.datatransfer.InPlaceDataTransferFactory  \
--mimeExtractorRepo ../policy/mime-extractor-map.xml \
--noRecur 2>&1 |\
tee -a $TEMPLOG 
fi

cd $FILEPATH


tar -cvvzf ${TEMPLOG}_met.tar *.met 

#rm *.met
cp $TEMPLOG $FILEPATH
cp ${TEMPLOG}_met.tar.gz $FILEPATH
echo "Finished scanning $FILEPATH"
