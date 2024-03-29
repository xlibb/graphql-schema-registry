// Copyright (c) 2024 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import graphql_schema_registry.datasource;
import ballerina/file;
import ballerina/io;

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
            string[] versions = check self.supergraphVersions();
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
            datasource:SubgraphId[] subgraphIds = check self.getSupergraphSubgraphsFromVersion(version);

            datasource:Subgraph[] subgraphs = [];
            foreach datasource:SubgraphId id in subgraphIds {
                datasource:Subgraph subgraph = check self->/subgraphs/[id.name]/[id.version];
                subgraphs.push(subgraph);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        lock {
            string[] versions = check self.supergraphVersions();
            if self.hasVersion(versions, data.version) {
                return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
            }

            string supergraphLocation = check self.joinPath(self.supergraphs, data.version);
            check self.createDir(supergraphLocation);

            datasource:Supergraph supergraph = {
                version: data.version,
                schema: data.schema,
                apiSchema: data.apiSchema
            };
            datasource:SubgraphId[] subgraphIds = data.clone().subgraphs;
            check self.writeRecord(check self.joinPath(supergraphLocation, SUPERGRAPH_FILE_NAME), supergraph.clone().toJson());
            check self.writeRecord(check self.joinPath(supergraphLocation, SUBGRAPHS_FILE_NAME), subgraphIds.clone().toJson());
        }
    }

    isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate data) returns datasource:Error? {
        lock {
            datasource:Supergraph supergraph = check self->/supergraphs/[version];
            datasource:Supergraph updatedSupergraph = supergraph.clone();
            updatedSupergraph.schema = data.schema;
            updatedSupergraph.apiSchema = data.apiSchema;

            string supergraphLocation = check self.joinPath(self.supergraphs, version);
            check self.writeRecord(check self.joinPath(supergraphLocation, SUPERGRAPH_FILE_NAME), updatedSupergraph.clone().toJson());
            check self.writeRecord(check self.joinPath(supergraphLocation, SUBGRAPHS_FILE_NAME), data.subgraphs.clone().toJson());
        }
    }

    isolated function supergraphVersions() returns string[]|datasource:Error {
        lock {
            return check self.getFileNames(self.supergraphs).clone();
        }
    }

    isolated resource function get subgraphs(string? name = ()) returns datasource:Subgraph[]|datasource:Error {
        lock {
            datasource:Subgraph[] subgraphs = [];
            string[] subgraphNames = name is () ? check self.getFileNames(self.subgraphs) : [ name ];
            foreach string subgraphName in subgraphNames {
                datasource:Subgraph[] subgraphGroup = check self->/subgraphs/[subgraphName];
                subgraphs.push(...subgraphGroup);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function get subgraphs/[string name]/[string version]() returns datasource:Subgraph|datasource:Error {
        lock {
            json subgraphJson = check self.readRecord(check self.joinPath(self.subgraphs, name, version));
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
            string[]|datasource:Error subgraphVersions = self.getFileNames(subgraphPath);
            if subgraphVersions is datasource:Error {
                return [];
            }

            datasource:Subgraph[] subgraphs = [];
            foreach string version in subgraphVersions {
                datasource:Subgraph subgraph = check self->/subgraphs/[name]/[version];
                subgraphs.push(subgraph);
            }
            return subgraphs.clone();
        }
    }

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns datasource:Subgraph|datasource:Error {
        lock {
            string subgraphLocation = check self.joinPath(self.subgraphs, data.name);
            file:Error? err = check self.checkAndCreateDir(subgraphLocation);
            if err is file:Error {
                return error datasource:Error(err.message());
            }
            int[] versions = (check self.getFileNames(subgraphLocation)).map(i => check self.subgraphIdFromString(i)).sort("descending");
            string nextSubgraphVersion = ((versions.length() > 0 ? versions[0] : 0) + 1).toString();
            datasource:Subgraph subgraph = {
                version: nextSubgraphVersion,
                name: data.name,
                url: data.url,
                schema: data.schema
            };
            check self.writeRecord(check self.joinPath(subgraphLocation, nextSubgraphVersion), subgraph.toJson());
            return subgraph.clone();
        }
    }

    isolated function getSupergraphSubgraphsFromVersion(string version) returns datasource:SubgraphId[]|datasource:Error {
        lock {
            string subgraphsLocation = check self.joinPath(self.supergraphs, version, SUBGRAPHS_FILE_NAME);
            json subgraphsJson = check self.readRecord(subgraphsLocation);
            datasource:SubgraphId[]|error subgraphIds = subgraphsJson.fromJsonWithType();
            if subgraphIds is error {
                return error datasource:Error(string `Unable to convert into SupergraphSubgraph[].`);
            }
            return subgraphIds.cloneReadOnly();
        }
    }

    isolated function hasVersion(string[] versions, string version) returns boolean {
        return versions.indexOf(version) !is ();
    }

    isolated function writeRecord(string location, json records) returns datasource:Error? {
        io:Error? result = io:fileWriteJson(location, records);
        if result is io:Error {
            return error datasource:Error(result.message());
        }
    }

    isolated function readRecord(string location) returns json|datasource:Error {
        json|io:Error jsonRecord = io:fileReadJson(location);
        if jsonRecord is io:Error {
            return error datasource:Error(string `Unable to read '${location}'`);
        }
        return jsonRecord;
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
