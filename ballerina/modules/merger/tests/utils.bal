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

import ballerina/io;
import ballerina/file;
import graphql_schema_registry.parser;

type TestSchemas record {|
    parser:__Schema parsed;
    parser:__Schema merged;
|};

string testResourcesPath = check file:joinPath("modules", "merger", "tests", "resources");

function getSubgraphsFromFileName(string folderName, string subgraph_prefix) returns Subgraph[]|error {
    Subgraph[] subgraphs = [];

    string path = check file:joinPath(testResourcesPath, "subgraph_sdls", folderName);
    file:MetaData[] & readonly readDir = check file:readDir(path);
    
    int subgraph_no = 1;
    foreach file:MetaData data in readDir {
        if !data.dir && data.absPath.endsWith(".graphql") {
            string sdl = check io:fileReadString(data.absPath);
            parser:Parser parser = new(sdl, parser:SUBGRAPH_SCHEMA);
            parser:__Schema|parser:SchemaError[] parsedSchema = parser.parse();
            if parsedSchema is parser:SchemaError[] {
                return parser:getSchemaErrorsAsError(parsedSchema);
            }

            subgraphs.push(
                {
                    name: string `${subgraph_prefix}${subgraph_no}`,
                    url: string `http://${subgraph_prefix}${subgraph_no}`,
                    schema: parsedSchema
                }
            );

            subgraph_no += 1;
        }
    }
    return subgraphs;
}

type ErrorMessages string[];
function getExpectedErrorMessages(string testName) returns string[]|error {
    string path = check file:joinPath(testResourcesPath, "expected_errors", string `${testName}.json`);
    json errorsJson = check io:fileReadJson(path);
    return check errorsJson.cloneWithType(ErrorMessages);
}

function getExpectedHintMessages(string testName) returns string[]|error {
    string path = check file:joinPath(testResourcesPath, "expected_hints", string `${testName}.json`);
    json errorsJson = check io:fileReadJson(path);
    return check errorsJson.cloneWithType(ErrorMessages);
}

function getSupergraphSdlFromFileName(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath(testResourcesPath, "expected_supergraphs", gqlFileName);
    return check io:fileReadString(path);
}

function getSupergraphFromFileName(string fileName) returns parser:__Schema|error {
    string sdl = check getSupergraphSdlFromFileName(fileName);
    parser:Parser parser = new(sdl, parser:SCHEMA);
    parser:__Schema|parser:SchemaError[] parsedSchema = parser.parse();
    if parsedSchema is parser:SchemaError[] {
        return parser:getSchemaErrorsAsError(parsedSchema);
    }
    return parsedSchema;
}

function getSchemas(string fileName, string subgraph_prefix = "subg") returns [parser:__Schema, Subgraph[]]|error {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(fileName, subgraph_prefix);
    parser:__Schema supergraph = check getSupergraphFromFileName(fileName);
    return [supergraph, subgraphs];
}

function getMergedAndParsedSchemas(string fileName) returns TestSchemas|error {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas(fileName);
    SupergraphMergeResult|MergeError[]|InternalError|error merged = (check new Merger(schemas[1])).merge();
    if merged is SupergraphMergeResult {
        return {
            parsed: schemas[0],
            merged: merged.result.schema
        };
    } else if merged is MergeError[] {
        string[] errorMsgs = [];
        foreach MergeError err in merged {
            errorMsgs.push(err.message());
        }
        return error(string `Supergraph merge failure. ${string:'join("\n", ...errorMsgs)}`);
    } else {
        return merged;
    }
}
