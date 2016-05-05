#!/bin/bash
BINDIR=/celgene/software/apache-oodt-0.6/bin
CURRDATE=$( date +"%m-%d-%y")
FILEPATH=$(pwd)
filesOrDirs=$1
TEMPLOG=$FILEPATH/crawler-${CURRDATE}.log


echo "Processing $FILEPATH "> $TEMPLOG
echo "Data       $CURRDATE" >> $TEMPLOG

cd $BINDIR

mkdir -p ${HOME}/oodt-logs/

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


#tar -cvvzf $FILEPATH/crawler-${CURRDATE}.tar *.met 

#rm *.met

echo "Finished scanning $FILEPATH"
