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
import ballerina/io;

@test:Config {
    groups: ["merger", "sdls"],
    dataProvider: dataProviderMergedSdls
}
function testMergedSdls(string fileName) returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas(fileName);

    string exportedSdl = check exporter:export(schemas.merged);
    string expectedSdl = check getSupergraphSdlFromFileName(fileName);
    if expectedSdl !== exportedSdl {
        check io:fileWriteString(string `./modules/merger/tests/resources/expected_supergraphs/${fileName}_1.graphql`, exportedSdl);
    }
    test:assertEquals(exportedSdl, check getSupergraphSdlFromFileName(fileName));
}

function dataProviderMergedSdls() returns [string][] {
    return [
        ["directive_definition_presence"],
        ["multiple_subgraphs_conflicting_compatible_enum_types"],
        ["multiple_subgraphs_conflicting_compatible_input_types"],
        ["multiple_subgraphs_conflicting_compatible_interfaces"],
        ["multiple_subgraphs_conflicting_compatible_objects"],
        ["multiple_subgraphs_conflicting_compatible_output_types"],
        ["multiple_subgraphs_conflicting_compatible_union_types"],
        ["multiple_subgraphs_conflicting_interface_implements"],
        ["multiple_subgraphs_join__Graph"],
        ["multiple_subgraphs_join__type"],
        ["multiple_subgraphs_key"],
        ["multiple_subgraphs_nonconflicting_types"],
        ["multiple_subgraphs_shareable"],
        ["multiple_subgraphs_types_description"],
        ["single_subgraph_join__type"],
        ["supergraph_definitions"],
        ["full_schema"]
    ];
}
