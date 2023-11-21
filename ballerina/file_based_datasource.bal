import graphql_schema_registry.datasource as datasource;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;

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
        datasource:SupergraphSchema supergraphSchema = check self.readRecord(location);
        return supergraphSchema;
    }

    public function register(datasource:SupergraphSchema records) returns datasource:SupergraphSchema|datasource:DatasourceError {
        datasource:Version nextVersion = check self.getNextVersion();
        string newVersionLocation = check self.getRecordLocation(nextVersion);
        datasource:SupergraphSchema updatedRecords = datasource:createSupergraphRecord(records.schema, records.subgraphs, nextVersion);
        io:Error? fileWriteResult = self.writeRecord(newVersionLocation, updatedRecords);
        if fileWriteResult is io:Error {
            return error datasource:DatasourceError(fileWriteResult.message());
        }
        return updatedRecords;
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

    function writeRecord(string location, datasource:SupergraphSchema records) returns io:Error? {
        return check io:fileWriteString(location, records.toJsonString().toBytes().toBase64());
        // return check io:fileWriteJson(location, records.toJson());
    }

    function readRecord(string location) returns datasource:SupergraphSchema|datasource:DatasourceError {
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

    function encodeRecord(datasource:SupergraphSchema schemaRecord) returns string {
        return schemaRecord.toJsonString().toBytes().toBase64();
    }

    function decodeRecord(string encodedRecord) returns datasource:SupergraphSchema|datasource:DatasourceError {
        byte[]|error data = array:fromBase64(encodedRecord);
        if data is error {
            return error datasource:DatasourceError(string `Unable to decode base64. ${data.message()}`);
        }
        string|error jsonString = string:fromBytes(data);
        if jsonString is error {
            return error datasource:DatasourceError(string `Unable to read json. ${jsonString.message()}`);
        }
        datasource:SupergraphSchema|error schemaRecord = jsonString.fromJsonStringWithType(datasource:SupergraphSchema);
        if schemaRecord is error {
            return error datasource:DatasourceError(string `Unable to create type from json. ${schemaRecord.message()}`);
        }
        return schemaRecord;

    }
}