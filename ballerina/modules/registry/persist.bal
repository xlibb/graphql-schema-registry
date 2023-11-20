import ballerina/file;
import ballerina/io;
import ballerina/regex;

class Persist {

    private string location;

    public function init(string location) returns error? {
        self.location = location;
        if !(check file:test(self.location, file:IS_DIR)) {
            check file:createDir(self.location);
        }
    }

    public function register(SchemaSnapshot records) returns error? {
        Version nextVersion = check self.getNextVersion();
        string newVersionLocation = check self.getRecordLocation(nextVersion);
        check self.writeSchema(newVersionLocation, records);
    }

    public function getLatestSchemas() returns SchemaSnapshot?|error {
        Version? latestVersion = check self.getLatestVersion();
        if latestVersion is Version {
            return check self.getSchemasByVersion(latestVersion);
        } else {
            return ();
        }
    }

    public function getSchemasByVerisonString(string versionStr) returns SchemaSnapshot|error {
        Version version = check getVersion(versionStr);
        return check self.getSchemasByVersion(version);
    }

    function getSchemasByVersion(Version version) returns SchemaSnapshot|error {
        string location = check self.getRecordLocation(version);
        json|io:Error readJson = io:fileReadJson(location);
        if readJson is io:Error {
            return error PersistError(readJson.message());
        }
        return readJson.cloneWithType();
    }

    function getVersions() returns Version[]|error {
        Version[] versions = [];
        file:MetaData[] & readonly readDir = check file:readDir(self.location);
        foreach file:MetaData metaData in readDir {
            string versionStr = check file:basename(metaData.absPath);
            versionStr = regex:replace(versionStr, FILE_EXTENSION_REGEX, "");
            versions.push(check getVersion(versionStr));
        }
        return versions;
    }

    function getLatestVersion() returns Version?|error {
        Version[] versions = check self.getVersions();
        if versions.length() > 0 {
            return versions[versions.length() - 1];
        } else {
            return ();
        }
    }

    function getNextVersion() returns Version|error {
        Version? latestVersion = check self.getLatestVersion();
        return incrementVersion(latestVersion ?: createInitialVersion());
    }

    function writeSchema(string location, SchemaSnapshot records) returns error? {
        return check io:fileWriteJson(location, records.toJson());
    }

    function getRecordLocation(Version version) returns string|error {
        return check file:joinPath(self.location, getVersionAsString(version) + ".json");
    }
}