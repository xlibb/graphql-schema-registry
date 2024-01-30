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
    groups: ["custom", "enum_values"],
    dataProvider: dataProviderEnumValues
}
function testEnumValues(string fileName, string typeName, __EnumValue[] expectedEnumValues) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types.get(typeName).enumValues, expectedEnumValues);
 }

function dataProviderEnumValues() returns [string, string, __EnumValue[]][] {
    return [ 
        ["enum_values", "Status",
            [ { name: "ON_HOLD" }, { name: "COMPLETED" }, { name: "FAILED" } ]
        ],
        ["enum_values_description", "Status",
            [ { name: "ON_HOLD", description: "Project is on hold" } ]
        ],
        ["enum_values_applied_directive", "Status",
            [{ name: "ON_HOLD", appliedDirectives: [ 
                {
                    args: {
                        "reason": { value: "Added PAUSED", definition: builtInTypes.get(STRING) }
                    },
                    definition: builtInDirectives.get(DEPRECATED_DIR)
                }
            ],
                isDeprecated: true,
                deprecationReason: "Added PAUSED"
            }]
        ]
    ];
}
