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
    groups: ["merger", "compatible", "directives", "filter"],
    dataProvider: dataProviderDirectiveDefinitionPresence
}
function testDirectiveDefinitionPresence(TestSchemas schemas, string directiveName) {
    test:assertEquals(
        schemas.merged.directives.hasKey(directiveName), 
        schemas.parsed.directives.hasKey(directiveName)
    );
    if (schemas.merged.directives.hasKey(directiveName) && schemas.parsed.directives.hasKey(directiveName)) {
        test:assertEquals(
            schemas.merged.directives.get(directiveName),
            schemas.parsed.directives.get(directiveName)
        );
    }
}

function dataProviderDirectiveDefinitionPresence() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("directive_definition_presence");

    return [
        [ schemas, "foo" ],
        [ schemas, "executableFoo" ]
    ];
}
