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
    groups: ["merger", "compatible", "join__type"],
    dataProvider: dataProviderJoinType
}
function testJoinType(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(
        schemas.merged.types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR), 
        schemas.parsed.types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR)
    );
}

function dataProviderJoinType() returns [TestSchemas, string][]|error {
    TestSchemas multiple_subgraph_schemas = check getMergedAndParsedSchemas("multiple_subgraphs_join__type");
    TestSchemas single_subgraph_schemas = check getMergedAndParsedSchemas("single_subgraph_join__type");

    return [
        [multiple_subgraph_schemas, "Email"],
        [multiple_subgraph_schemas, "Bux"],
        [multiple_subgraph_schemas, "Bar"],
        [multiple_subgraph_schemas, "Foo"],
        [multiple_subgraph_schemas, "Waldo"],
        [single_subgraph_schemas, "SearchQuery"],
        [single_subgraph_schemas, "Person"],
        [single_subgraph_schemas, "Salary"],
        [single_subgraph_schemas, "DegreeStatus"],
        [single_subgraph_schemas, "Academic"],
        [single_subgraph_schemas, "Student"],
        [single_subgraph_schemas, "Teacher"],
        [single_subgraph_schemas, "Query"]
    ];
}
