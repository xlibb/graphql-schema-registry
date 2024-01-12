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
    groups: ["merger", "compatible", "default_values"],
    dataProvider: dataProviderConflictCompatibleDefaultValues
}
function testConflictCompatibleDefaultValues(TestSchemas schemas, string typeName, string fieldName) {
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

function dataProviderConflictCompatibleDefaultValues() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_default_values");

    return [
        [ schemas, typeName, "name" ],
        [ schemas, typeName, "age" ]
    ];
}