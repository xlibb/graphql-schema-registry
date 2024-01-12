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
    groups: ["merger", "compatible", "union_types"]
}
function testConflictUnionTypesAppliedDirectives() returns error? {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_union_types");

    foreach parser:__AppliedDirective expectedAppliedDirective in schemas.parsed.types.get(typeName).appliedDirectives {
        test:assertTrue(schemas.merged.types.get(typeName).appliedDirectives
                                                             .some(a => a == expectedAppliedDirective)
        );
    }
}

@test:Config {
    groups: ["merger", "compatible", "union_types"]
}
function testConflictUnionTypesPossibleTypes() returns error? {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_union_types");

    parser:__Type[]? actualPossibleTypes = schemas.merged.types.get(typeName).possibleTypes;
    parser:__Type[]? expectedPossibleTypes = schemas.parsed.types.get(typeName).possibleTypes;

    if actualPossibleTypes !is () && expectedPossibleTypes !is () {
        test:assertEquals( actualPossibleTypes, expectedPossibleTypes );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}