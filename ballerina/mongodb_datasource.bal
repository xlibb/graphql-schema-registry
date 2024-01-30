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
import ballerinax/mongodb;

configurable mongodb:ConnectionConfig mongoConfig = ?;

type MongoErrors mongodb:DatabaseError|mongodb:ApplicationError|error;

public isolated client class MongodbDatasource {
    *datasource:Datasource;

    private final mongodb:Client mongoClient;
    private final string SUPERGRAPHS = "supergraphs";
    private final string SUBGRAPHS = "subgraphs";

    isolated function init() returns error? {
        self.mongoClient = check new(mongoConfig);
    }

    isolated resource function get supergraphs() returns datasource:Supergraph[]|datasource:Error {
        datasource:Supergraph[] supergraphs = [];
        string[] versions = check self.supergraphVersions();
        foreach string version in versions {
            datasource:Supergraph supergraph = check self->/supergraphs/[version];
            supergraphs.push(supergraph);
        }
        return supergraphs;
    }

    isolated resource function get supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
        stream<datasource:Supergraph, error?>|MongoErrors result = self.mongoClient->find(
                                                                                    self.SUPERGRAPHS,
                                                                                    filter = { version },
                                                                                    projection = { 
                                                                                        _id: 0, 
                                                                                        subgraphs: 0 
                                                                                    });
        if result !is stream<datasource:Supergraph, error?> {
            return error datasource:Error(result.message());
        }
        record {|datasource:Supergraph value;|}|error? supergraph = result.next();
        if supergraph is error {
            return error datasource:Error(supergraph.message());
        }
        if supergraph is () {
            return error datasource:Error(string `No supergraph found with version '${version}'`);
        }

        return supergraph.value;
    }

    isolated resource function get supergraphs/[string version]/subgraphs() returns datasource:Subgraph[]|datasource:Error {
        stream<record { datasource:SubgraphId[] subgraphs; }, error?>|MongoErrors results = self.mongoClient->find(
                                                                                                self.SUPERGRAPHS, 
                                                                                                filter = { version }, 
                                                                                                projection = { 
                                                                                                    _id: 0, 
                                                                                                    subgraphs: 1 
                                                                                                });
        if results !is stream<record { datasource:SubgraphId[] subgraphs; }, error?> {
            return error datasource:Error(results.message());
        }
        datasource:SubgraphId[][]|error subgraphRefs = from var result in results select result.subgraphs;
        if subgraphRefs is error {
            return error datasource:Error(subgraphRefs.message());
        }
        if subgraphRefs.length() == 0 {
            return error datasource:Error(string `No supergraph found with version '${version}'`);
        }

        datasource:Subgraph[] subgraphs = [];
        foreach var subgraphId in subgraphRefs[0] {
            datasource:Subgraph subgraph = check self->/subgraphs/[subgraphId.name]/[subgraphId.version];
            subgraphs.push(subgraph);
        }
        return subgraphs;
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        string[] versions = check self.supergraphVersions();
        if self.hasVersion(versions, data.version) {
            return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
        }

        mongodb:Error? insertResult = self.mongoClient->insert(data, self.SUPERGRAPHS);
        if insertResult is mongodb:DatabaseError {
            return error datasource:Error(insertResult.message());
        }
    }

    isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate data) returns datasource:Error? {
        int|mongodb:Error updateResult = self.mongoClient->update({ "$set": { 
                                            version: version,
                                            schema: data.schema,
                                            apiSchema: data.apiSchema,
                                            subgraphs: data.subgraphs
                                        }}, self.SUPERGRAPHS, filter = { version });
        if updateResult is mongodb:Error {
            return error datasource:Error(updateResult.message());
        }
    }

    isolated function supergraphVersions() returns string[]|datasource:Error {
        stream<record { string version; }, error?>|MongoErrors result = self.mongoClient->find(
                                                                            self.SUPERGRAPHS,
                                                                            projection = { version: 1 });
        if result !is stream<record { string version; }, error?> {
            return error datasource:Error(result.message());
        }
        string[]|error versions = from var supergraph in result select supergraph.version;
        if versions is error {
            return error datasource:Error(versions.message());
        }
        return versions;
    }

    isolated resource function get subgraphs(string? name = ()) returns datasource:Subgraph[]|datasource:Error {
        stream<datasource:Subgraph, error?>|MongoErrors result = self.mongoClient->find(
                                                                            self.SUBGRAPHS,
                                                                            filter = name is () ? {} : { name },
                                                                            projection = { _id: 0 });
        if result !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(result.message());
        }
        datasource:Subgraph[]|error subgraphs = from var subgraph in result select subgraph;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs;
    }

    isolated resource function get subgraphs/[string name]/[string version]() returns datasource:Subgraph|datasource:Error {
        stream<datasource:Subgraph, error?>|MongoErrors result = self.mongoClient->find(
                                                                        self.SUBGRAPHS,
                                                                        filter = { name, version },
                                                                        projection = { _id: 0 }, 
                                                                        'limit = 1);
        if result !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(result.message());
        }
        datasource:Subgraph[]|error subgraphs = from var subgraph in result limit 1 select subgraph;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        if subgraphs.length() <= 0 {
            return error datasource:Error(string `A subgraph with the given name '${name}' and version '${version}' doesn't exist.`);
        }
        return subgraphs[0];
    }

    isolated resource function get subgraphs/[string name]() returns datasource:Subgraph[]|datasource:Error {
        stream<datasource:Subgraph, error?>|MongoErrors result = self.mongoClient->find(
                                                                            self.SUBGRAPHS,
                                                                            filter = { name },
                                                                            projection = { _id: 0 });
        if result !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(result.message());
        }
        datasource:Subgraph[]|error subgraphs = from var subgraph in result select subgraph;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs;
    }

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns datasource:Subgraph|datasource:Error {
        int|mongodb:Error documentCount = self.mongoClient->countDocuments(
                                                                self.SUBGRAPHS, 
                                                                filter = { name: data.name });
        if documentCount is mongodb:Error {
            return error datasource:Error(documentCount.message());
        }
        int nextVersion = documentCount + 1;
        datasource:Subgraph subgraph = {
            version: nextVersion.toString(),
            name: data.name,
            url: data.url,
            schema: data.schema
        };
        mongodb:Error? insertResult = self.mongoClient->insert(subgraph, self.SUBGRAPHS);
        if insertResult is mongodb:DatabaseError {
            return error datasource:Error(insertResult.message());
        }
        return subgraph;
    }

    isolated function hasVersion(string[] versions, string version) returns boolean {
        return versions.indexOf(version) !is ();
    }
}
