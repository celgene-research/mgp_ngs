document=$1
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<delete><query>Filename:'${document}'</query></delete>'
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<commit />'
curl http://${SOLR_SERVER_IP}:${SOLR_SERVER_PORT}/solr/update -H "Content-type: text/xml" --data-binary '<optimize />'

