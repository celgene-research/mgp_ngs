###Import postgres to SOLR
Some information can be found at:
https://www.quora.com/How-to-use-solr-with-postgres-database

In case of Solr, a general approach is to use Data Import Handler (DIH for short). Config the full-import & delta-import sql properly, where delta import import data from database that changes since last import judging via timestamps (so, u need design schema with proper timestamps).


in **solrconfig.xml** we configure the Data Import Handler


<requestHandler name="/dataimport" class="org.apache.solr.handler.dataimport.DataImportHandler">
  <lst name="defaults">
    <str name="config">/path/to/my/DIHconfigfile.xml</str>
  </lst>
</requestHandler>

The only required parameter is the config parameter, which specifies the location of the DIH configuration file that contains specifications for the data source, how to fetch data, what data to fetch, and how to process it to generate the Solr documents to be posted to the index.

Install the Oracle JDK 
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install oracle-java7-installer

Download the **PostgreSQL JDBC driver**



Create the **DIHconfigfile.xml**

<dataConfig>
<!-- The first element is the dataSource, in this case an HSQLDB database.
     The path to the JDBC driver and the JDBC URL and login credentials are all specified here.
     Other permissible attributes include whether or not to autocommit to Solr, the batchsize
     used in the JDBC connection, a 'readOnly' flag. 
     The password attribute is optional if there is no password set for the DB.
-->
  <dataSource driver="org.hsqldb.jdbcDriver" url="jdbc:hsqldb:./example-DIH/hsqldb/ex" user="sa" password="secret"/>
<!--
Alternately the password can be encrypted as follows. This is the value obtained as a result of the command
openssl enc -aes-128-cbc -a -salt -in pwd.txt
password="U2FsdGVkX18QMjY0yfCqlfBMvAB4d3XkwY96L7gfO2o=" 
WHen the password is encrypted, you must provide an extra attribute
encryptKeyFile="/location/of/encryptionkey"
This file should a text file with a single line containing the encrypt/decrypt password
 
-->
<!-- A 'document' element follows, containing multiple 'entity' elements.
     Note that 'entity' elements can be nested, and this allows the entity
     relationships in the sample database to be mirrored here, so that we can
     generate a denormalized Solr record which may include multiple features
     for one item, for instance -->
  <document>
 
<!-- The possible attributes for the entity element are described below.
     Entity elements may contain one or more 'field' elements, which map
     the data source field names to Solr fields, and optionally specify
     per-field transformations -->
<!-- this entity is the 'root' entity. -->
    <entity name="item" query="select * from item"
            deltaQuery="select id from item where last_modified > '${dataimporter.last_index_time}'">
      <field column="NAME" name="name" />
 
<!-- This entity is nested and reflects the one-to-many relationship between an item and its multiple features.
     Note the use of variables; ${item.ID} is the value of the column 'ID' for the current item
     ('item' referring to the entity name)  -->
      <entity name="feature" 
              query="select DESCRIPTION from FEATURE where ITEM_ID='${item.ID}'"
              deltaQuery="select ITEM_ID from FEATURE where last_modified > '${dataimporter.last_index_time}'"
              parentDeltaQuery="select ID from item where ID=${feature.ITEM_ID}">
        <field name="features" column="DESCRIPTION" />
      </entity>
      <entity name="item_category"
              query="select CATEGORY_ID from item_category where ITEM_ID='${item.ID}'"
              deltaQuery="select ITEM_ID, CATEGORY_ID from item_category where last_modified > '${dataimporter.last_index_time}'"
              parentDeltaQuery="select ID from item where ID=${item_category.ITEM_ID}">
        <entity name="category"
                query="select DESCRIPTION from category where ID = '${item_category.CATEGORY_ID}'"
                deltaQuery="select ID from category where last_modified > '${dataimporter.last_index_time}'"
                parentDeltaQuery="select ITEM_ID, CATEGORY_ID from item_category where CATEGORY_ID=${category.ID}">
          <field column="description" name="cat" />
        </entity>
      </entity>
    </entity>
  </document>
</dataConfig>