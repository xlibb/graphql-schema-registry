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
    groups: ["differ"],
    dataProvider: dataProviderTestDiffer
}
function testDiffer(string testName) returns error? {
    var [newSchema, oldSchema] = check getSchemas(testName);
    SchemaDiff[] expectedDiffs = check getExpectedDiffs(testName);
    SchemaDiff[] actualDiffs = check diff(newSchema, oldSchema);

    test:assertEquals(actualDiffs, expectedDiffs);
}

function dataProviderTestDiffer() returns [string][] {
    return [
        ["type_removals_additions"],
        ["directive_removals_additions"],
        ["type_kind_changes"],
        ["type_description_change"],
        ["field_removals_additions"],
        ["field_descriptions"],
        ["field_deprecations"],
        ["field_types"],
        ["interface_implements"],
        ["field_arguments_types"],
        ["field_arguments_removals_additions"],
        ["field_arguments_descriptions"],
        ["field_arguments_default_values"],
        ["enum_values"],
        ["union_possible_types"],
        ["directive_descriptions"],
        ["directive_arguments_types"],
        ["directive_arguments_removals_additions"],
        ["directive_arguments_default_values"],
        ["directive_arguments_descriptions"]
    ];
}