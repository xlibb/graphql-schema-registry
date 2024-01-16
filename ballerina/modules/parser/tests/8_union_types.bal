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
    groups: ["custom", "types", "union"],
    dataProvider: dataProviderUnion
}
function testCustomUnionTypes(string fileName, __Type expectedUnionType) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);
    __Schema parsedSchema = check parseSdl(sdl);
    string? unionTypeName = expectedUnionType.name;
    if (unionTypeName != ()) {
        test:assertEquals(parsedSchema.types.get(unionTypeName), expectedUnionType);
    } else {
        test:assertFail("No Union type found");
    }
}

function dataProviderUnion() returns map<[string, __Type]> {
    __Type dogType = {
        kind: OBJECT,
        name: "Dog",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: []
    };
    __Type catType = {
        kind: OBJECT,
        name: "Cat",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: []
    };

    return {
        "1": [
            "union_types", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ]
            }
        ],
        "2": [
            "union_types_description", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ],
                description: "This is a union description"
            }
        ],
        "3": [
            "union_types_applied_directive", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ],
                appliedDirectives: [ 
                    {
                        args: {},
                        definition: {
                            name: "testDirective",
                            locations: [ UNION ],
                            args: {},
                            isRepeatable: false
                        }
                    }
                ]
            }
        ]
    };
}
