curl http://${NGS_SERVER_IP}:8081/solr/update -H "Content-type: text/xml" --data-binary '<delete><query>*:*</query></delete>'
curl http://${NGS_SERVER_IP}:8081/solr/update -H "Content-type: text/xml" --data-binary '<commit />'
curl http://${NGS_SERVER_IP}:8081/solr/update -H "Content-type: text/xml" --data-binary '<optimize />'

