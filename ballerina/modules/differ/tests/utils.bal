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

import ballerina/file;
import ballerina/io;
import graphql_schema_registry.parser;

string basePath = check file:joinPath("modules", "differ", "tests", "resources");

function getExpectedDiffs(string fileName) returns SchemaDiff[]|error {
    string expectedDiffPath = check file:joinPath(basePath, "expected_diffs", fileName + ".json");
    json expectedDiffsJson = check io:fileReadJson(expectedDiffPath);
    SchemaDiff[] expectedDiffs = check expectedDiffsJson.cloneWithType();
    return expectedDiffs;
}

function getSchemas(string fileName) returns [parser:__Schema, parser:__Schema]|error {
    string schemasPath = check file:joinPath(basePath, "schemas", fileName);
    string newSchemaSdlPath = check file:joinPath(schemasPath, "new.graphql");
    string oldSchemaSdlPath = check file:joinPath(schemasPath, "old.graphql");

    string newSchemaSdl = check io:fileReadString(newSchemaSdlPath);
    string oldSchemaSdl = check io:fileReadString(oldSchemaSdlPath);

    parser:__Schema|parser:SchemaError[] newSchema = new parser:Parser(newSchemaSdl, parser:SCHEMA).parse();
    if newSchema is parser:SchemaError[] {
        return parser:getSchemaErrorsAsError(newSchema);
    }
    parser:__Schema|parser:SchemaError[] oldSchema = new parser:Parser(oldSchemaSdl, parser:SCHEMA).parse();
    if oldSchema is parser:SchemaError[] {
        return parser:getSchemaErrorsAsError(oldSchema);
    }

    return [newSchema, oldSchema];
}
