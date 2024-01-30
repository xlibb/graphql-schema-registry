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

@test:Config {
    groups: ["merger", "negative"],
    dataProvider: dataProviderNegativeTest
}
function testNegative(string testname) returns error? {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(testname, "subg");
    SupergraphMergeResult|MergeError[] merged = check (check new Merger(subgraphs)).merge();
    if merged is MergeError[] {
        string[] expectedErrorMessages = check getExpectedErrorMessages(testname);
        string[] actualErrorMessages = merged.map(e => e.message());

        test:assertEquals(actualErrorMessages, expectedErrorMessages);
    } else {
        test:assertFail("Supergraph composed without errors");
    }
}

function dataProviderNegativeTest() returns [string][] {
    return [
        ["negative_type_mismatch"],
        ["negative_output_type_ref_mismatch"],
        ["negative_input_type_ref_mismatch"],
        ["negative_arg_type_ref_mismatch"],
        ["negative_missing_required_arg_type"],
        ["negative_missing_required_input_type_field"],
        ["negative_default_value_mismatch"],
        ["negative_invalid_field_sharing"],
        ["negative_enum_value_mismatch"]
    ];
}
