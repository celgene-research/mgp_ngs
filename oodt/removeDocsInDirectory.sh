#!/bin/bash

for  fname in `ls -d $PWD/*`
do
echo "removing $document from database"
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<delete><que
ry>FilePath:"'${document}'"</query></delete>'
done
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<commit />'
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<optimize />'

