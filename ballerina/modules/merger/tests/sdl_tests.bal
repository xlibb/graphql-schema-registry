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
        ["conflicting_enum_types"],
        ["conflicting_input_types"],
        ["conflicting_interfaces"],
        ["conflicting_objects"],
        ["conflicting_output_types"],
        ["conflicting_union_types"],
        ["conflicting_interface_implements"],
        ["conflicting_types_description"],
        ["federation_join__Graph"],
        ["federation_join__type"],
        ["federation_key"],
        ["federation_shareable"],
        ["non_conflicting_types"],
        ["single_subgraph_join__type"],
        ["supergraph_definitions"],
        ["full_schema"]
    ];
}
