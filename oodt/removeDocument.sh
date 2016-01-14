document=$1
curl http://10.130.5.63:8081/solr/update -H "Content-type: text/xml" --data-binary '<delete><query>Filename:'${document}'</query></delete>'
curl http://10.130.5.63:8081/solr/update -H "Content-type: text/xml" --data-binary '<commit />'
curl http://10.130.5.63:8081/solr/update -H "Content-type: text/xml" --data-binary '<optimize />'

