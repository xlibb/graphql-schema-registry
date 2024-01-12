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
    groups: ["merger", "compatible", "input_types"],
    dataProvider: dataProviderConflictCompatibleInputTypes
}
function testConflictCompatibleInputTypes(TestSchemas schemas, string typeName, string fieldName) {
    map<parser:__InputValue>? actualFields = schemas.merged.types.get(typeName).inputFields;
    map<parser:__InputValue>? expectedFields = schemas.parsed.types.get(typeName).inputFields;

    if actualFields !is () && expectedFields !is () {
        test:assertEquals(
            actualFields.get(fieldName),
            expectedFields.get(fieldName)
        );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}

function dataProviderConflictCompatibleInputTypes() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_input_types");

    return [
        [ schemas, typeName, "same_named_type" ],
        [ schemas, typeName, "same_non_nullable_type" ],
        [ schemas, typeName, "same_list_type" ],
        [ schemas, typeName, "same_multi_list_type" ],
        [ schemas, typeName, "same_multi_wrapping_type" ],
        [ schemas, typeName, "same_multi_outer_inner_wrapping_type" ],
        [ schemas, typeName, "diff_non_nullable_type_1" ],
        [ schemas, typeName, "diff_non_nullable_type_2" ],
        [ schemas, typeName, "diff_outer_non_nullable_type" ],
        [ schemas, typeName, "diff_inner_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_diff_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_diff_wrapping_type" ]
    ];
}