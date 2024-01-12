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

import ballerina/test;
import graphql_schema_registry.exporter;

@test:Config {
    groups: ["merger", "example"],
    dataProvider: dataProviderSimpleRealworldExample
}
function testSimpleRealworldExample(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}

function dataProviderSimpleRealworldExample() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("simple_realworld_example");

    return [
        [schemas, "Product"],
        [schemas, "Review"],
        [schemas, "ReviewInput"],
        [schemas, "User"],
        [schemas, "Query"],
        [schemas, "Mutation"]
    ];
}

@test:Config {
    groups: ["merger", "example"]
}
function testSimpleRealworldExampleExportSDL() returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("simple_realworld_example");

    string exportedSdl = check exporter:export(schemas.merged);
    test:assertEquals(exportedSdl, check getSupergraphSdlFromFileName("simple_realworld_example"));
}