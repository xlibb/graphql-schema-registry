import graphql_schema_registry.datasource;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
// import ballerina/uuid;

// type SchemaRecord record {|
//     string schema;
//     string apiSchema;
//     datasource:SubgraphSchema[] subgraphs;
//     datasource:Version version;
// |};

const SUPERGRAPH_FILE_NAME = "supergraph";
const SUBGRAPHS_FILE_NAME = "subgraphs";

isolated client class FileDatasource {
    *datasource:Datasource;

    private string location;
    private string subgraphs;
    private string supergraphs;

    public function init(string location) returns error? {
        self.location = location;
        self.supergraphs = check file:joinPath(location, SUPERGRAPH_FILE_NAME);
        self.subgraphs = check file:joinPath(location, SUBGRAPHS_FILE_NAME);

        lock {
            check self.checkAndCreateDir(self.location);
            check self.checkAndCreateDir(self.supergraphs);
            check self.checkAndCreateDir(self.subgraphs);
        }
    }

    isolated resource function get supergraphs() returns datasource:Supergraph[]|datasource:Error {
        lock {
            datasource:Supergraph[] supergraphs = [];
            string[] versions = check self->/versions;
            foreach string version in versions {
                datasource:Supergraph supergraph = check self->/supergraphs/[version];
                supergraphs.push(supergraph);
            }
            return supergraphs.clone();
        }
    }

    isolated resource function get supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
        lock {
            string supergraphLocation = check self.joinPath(self.supergraphs, version, SUPERGRAPH_FILE_NAME);
            json supergraphJson = check self.readRecord(supergraphLocation);
            datasource:Supergraph|error supergraph = supergraphJson.fromJsonWithType();
            if supergraph is error {
                return error datasource:Error("Unable to convert into Supergraph type");
            }
            return supergraph.clone();
        }
    }

    isolated resource function get supergraphs/[string version]/subgraphs() returns datasource:Subgraph[]|datasource:Error {
        lock {
            datasource:SupergraphSubgraph[] supergraphSubgraphs = check self.getSupergraphSubgraphsFromVersion(version);

            datasource:Subgraph[] subgraphs = [];
            foreach datasource:SupergraphSubgraph joinType in supergraphSubgraphs {
                datasource:Subgraph subgraph = check self->/subgraphs/[joinType.subgraphId]/[joinType.subgraphName];
                subgraphs.push(subgraph);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        lock {
            string[] versions = check self->/versions;
            if self.hasVersion(versions, data.version) {
                return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
            }

            string supergraphLocation = check self.joinPath(self.supergraphs, data.version);
            check self.createDir(supergraphLocation);
            check self.writeRecord(check self.joinPath(supergraphLocation, SUPERGRAPH_FILE_NAME), data.clone().toJson());
        }
    }

    // isolated resource function put supergraphsubgraphs/[int id](datasource:SupergraphSubgraphUpdate data) returns datasource:SupergraphSubgraph|datasource:Error {
    //     lock {
    //         // datasource:SupergraphSubgraph[] supergraphSubgraphs = check self.getSupergraphSubgraphsFromVersion(version);

    //     }
    // }

    // isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate value) returns datasource:Supergraph|datasource:Error {
    // }

    // isolated resource function delete supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
    // }

    isolated resource function get versions() returns string[]|datasource:Error {
        lock {
            return check self.getFileNames(self.supergraphs).clone();
        }
    }

    isolated resource function get subgraphs() returns datasource:Subgraph[]|datasource:Error {
        lock {
            datasource:Subgraph[] subgraphs = [];
            string[] subgraphNames = check self.getFileNames(self.subgraphs);
            foreach string subgraphName in subgraphNames {
                datasource:Subgraph[] subgraphGroup = check self->/subgraphs/[subgraphName];
                subgraphs.push(...subgraphGroup);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function get subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
        lock {
            json subgraphJson = check self.readRecord(check self.joinPath(self.subgraphs, name, id.toString()));
            datasource:Subgraph|error subgraph = subgraphJson.fromJsonWithType();
            if subgraph is error {
                return error datasource:Error("Unable to convert into Subgraph");
            }
            return subgraph.clone();
        }
    }

    isolated resource function get subgraphs/[string name]() returns datasource:Subgraph[]|datasource:Error {
        lock {
            string subgraphPath = check self.joinPath(self.subgraphs, name);
            string[]|datasource:Error subgraphIds = self.getFileNames(subgraphPath);
            if subgraphIds is datasource:Error {
                return [];
            }

            datasource:Subgraph[] subgraphs = [];
            foreach string subgraphId in subgraphIds {
                int id = check self.subgraphIdFromString(subgraphId);
                datasource:Subgraph subgraph = check self->/subgraphs/[id]/[name];
                subgraphs.push(subgraph);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns [int, string]|datasource:Error {
        lock {
            string subgraphLocation = check self.joinPath(self.subgraphs, data.name);
            file:Error? err = check self.checkAndCreateDir(subgraphLocation);
            if err is file:Error {
                return error datasource:Error(err.message());
            }
            int[] ids = (check self.getFileNames(subgraphLocation)).map(i => check self.subgraphIdFromString(i)).sort("descending");
            int nextId = (ids.length() > 0 ? ids[0] : 0) + 1;
            datasource:Subgraph subgraph = {
                id: nextId,
                name: data.name,
                url: data.url,
                schema: data.schema
            };
            check self.writeRecord(check self.joinPath(subgraphLocation, nextId.toString()), subgraph.toJson());
            return [nextId, data.name];
        }
    }

    // isolated resource function put subgraphs/[int id]/[string name](datasource:SubgraphUpdate value) returns datasource:Subgraph|datasource:Error {
    // }

    // isolated resource function delete subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
    // }

    // isolated resource function get supergraphsubgraphs() returns datasource:SupergraphSubgraph[]|datasource:Error {
    //     lock {
    //         return self.supergraphSubgraphTable.toArray().clone();
    //     }
    // }

    // isolated resource function get supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }

    isolated resource function get supergraphsubgraphs/[int subgraphId]/[string subgraphName]/[string supergraphVersion]() returns datasource:SupergraphSubgraph|datasource:Error {
        datasource:SupergraphSubgraph[] supergraphSubgraphs = check self.getSupergraphSubgraphsFromVersion(supergraphVersion);
        datasource:SupergraphSubgraph[] result = supergraphSubgraphs.filter(s => s.subgraphId == subgraphId && s.subgraphName == subgraphName && s.supergraphVersion == supergraphVersion);
        if result.length() > 0 {
            return result[0];
        } else {
            return error datasource:Error("Cannot find SupergraphSubgraph with given parameters.");
        }
    }

    isolated resource function post supergraphsubgraphs(datasource:SupergraphSubgraphInsert[] data) returns int[]|datasource:Error {
        map<datasource:SupergraphSubgraphInsert[]> groupedData = {};
        foreach datasource:SupergraphSubgraphInsert insert in data {
            if groupedData.hasKey(insert.supergraphVersion) {
                groupedData.get(insert.supergraphVersion).push(insert);
            } else {
                groupedData[insert.supergraphVersion] = [ insert ];
            }
        }
        lock {
            foreach [string, datasource:SupergraphSubgraphInsert[]] [version, subgraphData] in groupedData.clone().entries() {
                string[] versions = check self->/versions;
                if !self.hasVersion(versions, version) {
                    return error datasource:Error(string `Cannot find a supergraph with the given version '${version}'`);
                }
                string supergraphLocation = check self.joinPath(self.supergraphs, version);

                datasource:SupergraphSubgraph[] records = [];
                int i = 0;
                foreach datasource:SupergraphSubgraphInsert insertData in subgraphData {
                    records.push({
                        id: i.cloneReadOnly(),
                        subgraphName: insertData.subgraphName,
                        subgraphId: insertData.subgraphId,
                        supergraphVersion: insertData.supergraphVersion
                    });
                    i += 1;
                }
                check self.writeRecord(check self.joinPath(supergraphLocation, SUBGRAPHS_FILE_NAME), records.toJson());
            }
            return [];
        }
    }

    isolated resource function put supergraphsubgraphs/[int id](datasource:SupergraphSubgraphUpdate data) returns datasource:SupergraphSubgraph|datasource:Error {
        lock {
            datasource:SupergraphSubgraph? updatedSupergraphSubgraph = ();
            datasource:SupergraphSubgraph[] supergraphSubgraphs = check self.getSupergraphSubgraphsFromVersion(data.supergraphVersion);
            datasource:SupergraphSubgraph[]|error updatedSupergraphSubgraphs = supergraphSubgraphs.cloneWithType();
            if updatedSupergraphSubgraphs is error {
                return error datasource:Error("Cannot create a mutable copy of SupergraphSubgraphs");
            }
            foreach datasource:SupergraphSubgraph supergraphSubgraph in updatedSupergraphSubgraphs {
                if supergraphSubgraph.id == id {
                    supergraphSubgraph.subgraphId = data.subgraphId;
                    updatedSupergraphSubgraph = supergraphSubgraph;
                }
            }
            if updatedSupergraphSubgraph is () {
                return error datasource:Error(string `No SupergraphSubgraph found with the id '${id}'`);
            }
            string supergraphLocation = check self.joinPath(self.supergraphs, data.supergraphVersion);
            check self.writeRecord(check self.joinPath(supergraphLocation, SUBGRAPHS_FILE_NAME), updatedSupergraphSubgraphs.toJson());
            return updatedSupergraphSubgraph.cloneReadOnly();
        }
    }

    // isolated resource function delete supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }

    isolated function getSupergraphSubgraphsFromVersion(string version) returns datasource:SupergraphSubgraph[]|datasource:Error {
        lock {
            string subgraphsLocation = check self.joinPath(self.supergraphs, version, SUBGRAPHS_FILE_NAME);
            json subgraphsJson = check self.readRecord(subgraphsLocation);
            datasource:SupergraphSubgraph[]|error supergraphSubgraphs = subgraphsJson.fromJsonWithType();
            if supergraphSubgraphs is error {
                return error datasource:Error(string `Unable to convert into SupergraphSubgraph[].`);
            }
            return supergraphSubgraphs.cloneReadOnly();
        }
    }

    isolated function hasVersion(string[] versions, string version) returns boolean {
        return versions.indexOf(version) !is ();
    }

    isolated function writeRecord(string location, json records) returns datasource:Error? {
        io:Error? result = io:fileWriteString(location, self.encodeRecord(records.toJsonString()));
        if result is io:Error {
            return error datasource:Error(result.message());
        }
    }

    isolated function readRecord(string location) returns json|datasource:Error {
        string|io:Error encodedRecord = io:fileReadString(location);
        if encodedRecord is io:Error {
            return error datasource:Error(string `Unable to read '${location}'`);
        }
        return check self.decodeRecord(encodedRecord);
    }

    isolated function getFileNames(string location) returns string[]|datasource:Error {
        string[] versions = [];
        file:MetaData[] & readonly|file:Error readDir = file:readDir(location);
        if readDir is file:Error {
            return error datasource:Error(readDir.message());
        }

        foreach file:MetaData metaData in readDir {
            string|file:Error fileName = file:basename(metaData.absPath);
            if fileName is file:Error {
                return error datasource:Error(fileName.message());
            }
            versions.push(fileName);
        }
        return versions;
    }

    isolated function encodeRecord(string jsonString) returns string {
        return jsonString.toBytes().toBase64();
    }

    isolated function decodeRecord(string encodedRecord) returns json|datasource:Error {
        byte[]|error data = array:fromBase64(encodedRecord);
        if data is error {
            return error datasource:Error(string `Unable to decode base64. ${data.message()}`);
        }
        string|error jsonString = string:fromBytes(data);
        if jsonString is error {
            return error datasource:Error(string `Unable to read json. ${jsonString.message()}`);
        }
        json|error schemaRecord = jsonString.fromJsonString();
        if schemaRecord is error {
            return error datasource:Error(string `Unable to create type from json. ${schemaRecord.message()}`);
        }
        return schemaRecord;
    }

    isolated function checkAndCreateDir(string location) returns datasource:Error? {
        if !(check self.isDirectoryExists(location)) {
            check self.createDir(location);
        }
    }

    isolated function createDir(string location) returns datasource:Error? {
        file:Error? err = file:createDir(location);
        if err is file:Error {
            return error datasource:Error(err.message());
        }
    }

    isolated function joinPath(string... locations) returns string|datasource:Error {
        string|file:Error path = file:joinPath(...locations);
        if path is file:Error {
            return error datasource:Error(path.message());
        }
        return path;
    }

    isolated function isDirectoryExists(string location) returns boolean|datasource:Error {
        boolean|file:Error test = file:test(location, file:IS_DIR);
        if test is file:Error {
            return error datasource:Error(test.message());
        }
        return test;
    }

    isolated function subgraphIdFromString(string strId) returns int|datasource:Error {
        int|error id = int:fromString(strId);
        if id is error {
            return error datasource:Error(id.message());
        }
        return id;
    }
}

// class FileDatasource {
//     *datasource:Datasource;

//     private string location;

//     public function init(string location) returns error? {
//         self.location = location;
//         if !(check file:test(self.location, file:IS_DIR)) {
//             check file:createDir(self.location);
//         }
//     }

//     public function getLatestSchemas() returns datasource:SupergraphSchema?|datasource:DatasourceError {
//         datasource:Version? latestVersion = check self.getLatestVersion();
//         if latestVersion is datasource:Version {
//             return check self.getSchemasByVersion(latestVersion);
//         } else {
//             return ();
//         }
//     }

//     public function getSchemasByVersion(datasource:Version version) returns datasource:SupergraphSchema|datasource:DatasourceError {
//         string location = check self.getRecordLocation(version);
//         SchemaRecord schemaRecord = check self.readRecord(location);
//         return self.schemaRecordToSupergraph(schemaRecord);
//     }

//     public function registerSupergraph(datasource:SupergraphSchema schema) returns datasource:SupergraphSchema|datasource:DatasourceError {
//         string newVersionLocation = check self.getRecordLocation(schema.version);
//         io:Error? fileWriteResult = self.writeRecord(newVersionLocation, self.SupergraphToSchemaRecord(schema));
//         if fileWriteResult is io:Error {
//             return error datasource:DatasourceError(fileWriteResult.message());
//         }
//         return schema;
//     }

//     public function registerSubgraph(datasource:InputSubgraph subgraph) returns datasource:SubgraphSchema {
//         return datasource:createSubgraphSdl(
//             id = uuid:createType4AsString(),
//             name = subgraph.name,
//             url = subgraph.url,
//             sdl = subgraph.sdl
//         );
//     }

//     public function getLatestVersion() returns datasource:Version?|datasource:DatasourceError {
//         datasource:Version[] versions = check self.getVersions();
//         if versions.length() > 0 {
//             return versions[versions.length() - 1];
//         } else {
//             return ();
//         }
//     }

//     function getVersions() returns datasource:Version[]|datasource:DatasourceError {
//         datasource:Version[] versions = [];
//         file:MetaData[] & readonly|file:Error readDir = file:readDir(self.location);
//         if readDir is file:Error {
//             return error datasource:DatasourceError(readDir.message());
//         }

//         foreach file:MetaData metaData in readDir {
//             string|file:Error fileName = file:basename(metaData.absPath);
//             if fileName is file:Error {
//                 return error datasource:DatasourceError(fileName.message());
//             }

//             datasource:Version|error version = datasource:getVersionFromString(fileName);
//             if version is error {
//                 return error datasource:DatasourceError(string `Unable to cast version '${fileName}'`);
//             }

//             versions.push(version);
//         }
//         return versions;
//     }

//     function getNextVersion() returns datasource:Version|datasource:DatasourceError {
//         datasource:Version? latestVersion = check self.getLatestVersion();
//         return datasource:incrementVersion(latestVersion ?: datasource:createInitialVersion());
//     }

//     function writeRecord(string location, SchemaRecord records) returns io:Error? {
//         return check io:fileWriteString(location, records.toJsonString().toBytes().toBase64());
//     }

//     function schemaRecordToSupergraph(SchemaRecord 'record) returns datasource:SupergraphSchema {
//         map<datasource:SubgraphSchema> subgraphs = {};
//         foreach datasource:SubgraphSchema subgraph in 'record.subgraphs {
//             subgraphs[subgraph.name] = subgraph;
//         }
//         return datasource:createSupergraphRecord(
//             schema = 'record.schema,
//             apiSchema = 'record.apiSchema,
//             subgraphs = subgraphs,
//             version = 'record.version
//         );
//     }

//     function SupergraphToSchemaRecord(datasource:SupergraphSchema schema) returns SchemaRecord {
//         return {
//             schema: schema.schema,
//             apiSchema: schema.apiSchema,
//             subgraphs: schema.subgraphs.toArray(),
//             version: schema.version
//         };
//     }

//     function readRecord(string location) returns SchemaRecord|datasource:DatasourceError {
//         string|io:Error encodedRecord = io:fileReadString(location);
//         if encodedRecord is io:Error {
//             return error datasource:DatasourceError(string `Unable to read '${location}'. ${encodedRecord.message()}`);
//         }
//         return check self.decodeRecord(encodedRecord);
//     }

//     function getRecordLocation(datasource:Version version) returns string|datasource:DatasourceError {
//         string|file:Error joinPath = file:joinPath(self.location, datasource:getVersionAsString(version));
//         if joinPath is file:Error {
//             return error datasource:DatasourceError(joinPath.message());
//         }
//         return joinPath;
//     }

//     function encodeRecord(SchemaRecord schemaRecord) returns string {
//         return schemaRecord.toJsonString().toBytes().toBase64();
//     }

//     function decodeRecord(string encodedRecord) returns SchemaRecord|datasource:DatasourceError {
//         byte[]|error data = array:fromBase64(encodedRecord);
//         if data is error {
//             return error datasource:DatasourceError(string `Unable to decode base64. ${data.message()}`);
//         }
//         string|error jsonString = string:fromBytes(data);
//         if jsonString is error {
//             return error datasource:DatasourceError(string `Unable to read json. ${jsonString.message()}`);
//         }
//         SchemaRecord|error schemaRecord = jsonString.fromJsonStringWithType(SchemaRecord);
//         if schemaRecord is error {
//             return error datasource:DatasourceError(string `Unable to create type from json. ${schemaRecord.message()}`);
//         }
//         return schemaRecord;

//     }
// }