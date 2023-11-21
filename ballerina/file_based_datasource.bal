import graphql_schema_registry.datasource as datasource;
import ballerina/file;
import ballerina/io;
import ballerina/regex;

const string FILE_EXTENSION_REGEX = "\\.[^.]+$";
const string PERSIST_EXTENSION = ".json";

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
        json|io:Error readJson = io:fileReadJson(location);
        if readJson is io:Error {
            return error datasource:DatasourceError(readJson.message());
        }
        datasource:SupergraphSchema|error supergraphSchema = readJson.cloneWithType();
        if supergraphSchema is error {
            return error datasource:DatasourceError(supergraphSchema.message());
        }
        return supergraphSchema;
    }

    public function register(datasource:SupergraphSchema records) returns datasource:SupergraphSchema|datasource:DatasourceError {
        datasource:Version nextVersion = check self.getNextVersion();
        string newVersionLocation = check self.getRecordLocation(nextVersion);
        datasource:SupergraphSchema updatedRecords = datasource:createSupergraphRecord(records.schema, records.subgraphs, nextVersion);
        io:Error? fileWriteResult = io:fileWriteJson(newVersionLocation, updatedRecords.toJson());
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

            string versionStr = regex:replace(fileName, FILE_EXTENSION_REGEX, "");
            datasource:Version|error version = datasource:getVersionFromString(versionStr);
            if version is error {
                return error datasource:DatasourceError(string `Unable to cast version '${versionStr}'`);
            }

            versions.push(version);
        }
        return versions;
    }

    function getNextVersion() returns datasource:Version|datasource:DatasourceError {
        datasource:Version? latestVersion = check self.getLatestVersion();
        return datasource:incrementVersion(latestVersion ?: datasource:createInitialVersion());
    }

    function writeSchema(string location, datasource:SupergraphSchema records) returns error? {
        return check io:fileWriteJson(location, records.toJson());
    }

    function getRecordLocation(datasource:Version version) returns string|datasource:DatasourceError {
        string|file:Error joinPath = file:joinPath(self.location, datasource:getVersionAsString(version) + PERSIST_EXTENSION);
        if joinPath is file:Error {
            return error datasource:DatasourceError(joinPath.message());
        }
        return joinPath;
    }
}