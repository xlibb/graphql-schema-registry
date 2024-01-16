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
    groups: ["builtin", "types", "root"]
}
function testRootOperationTypes() returns error? { 
    string sdl = check getGraphqlSdlFromFile("root_operation_types");
    __Type queryType = {
        kind: OBJECT,
        name: "Query",
        fields: {
            "name": { 
                name: "name",
                args: {}, 
                'type: builtInTypes.get(STRING) 
            }
        },
        interfaces: []
    };
    __Type mutationType = {
        kind: OBJECT,
        name: "Mutation",
        fields: {
            "number": { 
                name: "number",
                args: { 
                    "page": { 
                        name: "page", 
                        'type: builtInTypes.get(INT) 
                    }
                },
                'type: builtInTypes.get(FLOAT) 
            }
        },
        interfaces: []
    };
    __Type subscriptionType = {
        kind: OBJECT,
        name: "Subscription",
        fields: {
            "name": { 
                name: "name",
                args: {}, 
                'type: builtInTypes.get(STRING) 
            }
        },
        interfaces: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Query"],          queryType);
    test:assertEquals(parsedSchema.queryType,               queryType);
    test:assertEquals(parsedSchema.types["Mutation"],       mutationType);
    test:assertEquals(parsedSchema.mutationType,            mutationType);
    test:assertEquals(parsedSchema.types["Subscription"],   subscriptionType);
    test:assertEquals(parsedSchema.subscriptionType,        subscriptionType);
}
