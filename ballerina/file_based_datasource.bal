import graphql_schema_registry.datasource as datasource;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/uuid;

class FileDatasource {
    *datasource:Datasource;

    private string location;

    public function init(string location) returns error? {
        self.location = location;
        if !(check file:test(self.location, file:IS_DIR)) {
            check file:createDir(self.location);
        }
    }

    public function getLatestSchemas() returns datasource:SupergraphSchema?|datasource:DatasourceError {
        datasource:Version? latestVersion = check self.getLatestVersion();
        if latestVersion is datasource:Version {
            return check self.getSchemasByVersion(latestVersion);
        } else {
            return ();
        }
    }

    public function getSchemasByVersion(datasource:Version version) returns datasource:SupergraphSchema|datasource:DatasourceError {
        string location = check self.getRecordLocation(version);
        SchemaRecord schemaRecord = check self.readRecord(location);
        return self.schemaRecordToSupergraph(schemaRecord);
    }

    public function registerSupergraph(datasource:SupergraphSchema schema) returns datasource:SupergraphSchema|datasource:DatasourceError {
        string newVersionLocation = check self.getRecordLocation(schema.version);
        io:Error? fileWriteResult = self.writeRecord(newVersionLocation, self.SupergraphToSchemaRecord(schema));
        if fileWriteResult is io:Error {
            return error datasource:DatasourceError(fileWriteResult.message());
        }
        return schema;
    }

    public function registerSubgraph(datasource:InputSubgraph subgraph) returns datasource:SubgraphSchema {
        return datasource:createSubgraphSdl(
            id = uuid:createType4AsString(),
            name = subgraph.name,
            url = subgraph.url,
            sdl = subgraph.sdl
        );
    }

    public function getLatestVersion() returns datasource:Version?|datasource:DatasourceError {
        datasource:Version[] versions = check self.getVersions();
        if versions.length() > 0 {
            return versions[versions.length() - 1];
        } else {
            return ();
        }
    }

    function getVersions() returns datasource:Version[]|datasource:DatasourceError {
        datasource:Version[] versions = [];
        file:MetaData[] & readonly|file:Error readDir = file:readDir(self.location);
        if readDir is file:Error {
            return error datasource:DatasourceError(readDir.message());
        }

        foreach file:MetaData metaData in readDir {
            string|file:Error fileName = file:basename(metaData.absPath);
            if fileName is file:Error {
                return error datasource:DatasourceError(fileName.message());
            }

            datasource:Version|error version = datasource:getVersionFromString(fileName);
            if version is error {
                return error datasource:DatasourceError(string `Unable to cast version '${fileName}'`);
            }

            versions.push(version);
        }
        return versions;
    }

    function getNextVersion() returns datasource:Version|datasource:DatasourceError {
        datasource:Version? latestVersion = check self.getLatestVersion();
        return datasource:incrementVersion(latestVersion ?: datasource:createInitialVersion());
    }

    function writeRecord(string location, SchemaRecord records) returns io:Error? {
        return check io:fileWriteString(location, records.toJsonString().toBytes().toBase64());
    }

    function schemaRecordToSupergraph(SchemaRecord 'record) returns datasource:SupergraphSchema {
        map<datasource:SubgraphSchema> subgraphs = {};
        foreach datasource:SubgraphSchema subgraph in 'record.subgraphs {
            subgraphs[subgraph.name] = subgraph;
        }
        return datasource:createSupergraphRecord(
            schema = 'record.supergraph,
            subgraphs = subgraphs,
            version = 'record.version
        );
    }

    function SupergraphToSchemaRecord(datasource:SupergraphSchema schema) returns SchemaRecord {
        return {
            supergraph: schema.schema,
            subgraphs: schema.subgraphs.toArray(),
            version: schema.version
        };
    }

    function readRecord(string location) returns SchemaRecord|datasource:DatasourceError {
        string|io:Error encodedRecord = io:fileReadString(location);
        if encodedRecord is io:Error {
            return error datasource:DatasourceError(string `Unable to read '${location}'. ${encodedRecord.message()}`);
        }
        return check self.decodeRecord(encodedRecord);
    }

    function getRecordLocation(datasource:Version version) returns string|datasource:DatasourceError {
        string|file:Error joinPath = file:joinPath(self.location, datasource:getVersionAsString(version));
        if joinPath is file:Error {
            return error datasource:DatasourceError(joinPath.message());
        }
        return joinPath;
    }

    function encodeRecord(SchemaRecord schemaRecord) returns string {
        return schemaRecord.toJsonString().toBytes().toBase64();
    }

    function decodeRecord(string encodedRecord) returns SchemaRecord|datasource:DatasourceError {
        byte[]|error data = array:fromBase64(encodedRecord);
        if data is error {
            return error datasource:DatasourceError(string `Unable to decode base64. ${data.message()}`);
        }
        string|error jsonString = string:fromBytes(data);
        if jsonString is error {
            return error datasource:DatasourceError(string `Unable to read json. ${jsonString.message()}`);
        }
        SchemaRecord|error schemaRecord = jsonString.fromJsonStringWithType(SchemaRecord);
        if schemaRecord is error {
            return error datasource:DatasourceError(string `Unable to create type from json. ${schemaRecord.message()}`);
        }
        return schemaRecord;

    }
}