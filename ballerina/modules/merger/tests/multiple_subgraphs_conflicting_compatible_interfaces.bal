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
    groups: ["merger", "compatible", "interfaces", "conflict"],
    dataProvider: dataProviderConflictInterfaceTypesFields
}
function testConflictInterfaceTypeFields(TestSchemas schemas, string typeName, string fieldName) returns error? {
    map<parser:__Field>? actualFields = schemas.merged.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas.parsed.types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(
            actualFields.get(fieldName),
            expectedFields.get(fieldName)
        );
    } else {
        test:assertFail(string `Cannot find field on '${typeName}' '${fieldName}'`);
    }
}

function dataProviderConflictInterfaceTypesFields() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_interfaces");

    return [
        [ schemas, typeName, "name" ],
        [ schemas, typeName, "age" ],
        [ schemas, typeName, "avg" ],
        [ schemas, typeName, "isStudent" ],
        [ schemas, typeName, "isBux" ]
    ];
}
