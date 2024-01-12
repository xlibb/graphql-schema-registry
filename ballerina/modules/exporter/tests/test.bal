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
import graphql_schema_registry.parser;

@test:Config {
    groups: ["exporter"],
    dataProvider: dataProviderExporter
}
function testConflictCompatibleInputTypes(string fileName) returns error? {
    string expectedSdl = check getSchemaSdl(fileName);
    parser:__Schema|parser:SchemaError[] parsedResult = new parser:Parser(expectedSdl, parser:SCHEMA).parse();
    if parsedResult is parser:SchemaError[] {
        return parser:getSchemaErrorsAsError(parsedResult);
    }
    string actualSdl = check export(parsedResult);
    if expectedSdl != actualSdl {
        check writeSchemaSdl(fileName + "_new", actualSdl);
    }
    test:assertEquals(actualSdl, expectedSdl);
}

function dataProviderExporter() returns [string][] {
    return [
        ["multiple_subgraphs_realworld_example"],
        ["multiple_subgraphs_conflicting_objects"],
        ["multiple_subgraphs_conflicting_enum_types"],
        ["multiple_subgraphs_join__type_and_join__Graph"],
        ["multiple_subgraphs_key_directive"],
        ["multiple_subgraphs_conflicting_union_types"],
        ["multiple_subgraphs_conflicting_interface_implements"],
        ["multiple_subgraphs_conflicting_interfaces"],
        ["multiple_subgraphs_nonconflicting_interfaces"],
        ["multiple_subgraphs_conflicting_compatible_output_types"],
        ["interface_implements"],
        ["basic_type_definitions"],
        ["multiple_subgraphs_conflicting_compatible_input_types"]
    ];
}