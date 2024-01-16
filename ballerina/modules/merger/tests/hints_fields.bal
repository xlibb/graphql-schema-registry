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
    groups: ["merger", "hints"],
    dataProvider: dataProviderHintTest
}
function testHints(string testname) returns error? {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(testname, "subg");
    SupergraphMergeResult|MergeError[] merged = check (check new Merger(subgraphs)).merge();
    if merged is SupergraphMergeResult {
        string[] expectedHintMessages = check getExpectedHintMessages(testname);
        string[] actualHintMessages = printHints(merged.hints);

        test:assertEquals(actualHintMessages, expectedHintMessages);
    } else {
        test:assertFail("Supergraph composed without errors");
    }
}

function dataProviderHintTest() returns [string][] {
    return [
        ["hint_descriptions"],
        ["hint_fields_inconsistent_field"],
        ["hint_inconsistent_argument_presence"],
        ["hint_inconsistent_but_compatible_output_type"],
        ["hint_inconsistent_union_member"],
        ["hint_inconsistent_default_value_presence"],
        ["hint_inconsistent_but_compatible_input_type"]
    ];
}
