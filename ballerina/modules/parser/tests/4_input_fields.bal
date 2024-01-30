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
    groups: ["custom", "input_fields"],
    dataProvider: dataProviderInputFields
}
function testInputField(string fileName, string inputTypeName, map<__InputValue> inputFields) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types.get(inputTypeName).inputFields, inputFields);
 }

function dataProviderInputFields() returns [string, string, map<__InputValue>][] {
    return [ 
        ["input_fields", "SearchInput",
            {
                "keyword":  { name: "keyword",  'type: builtInTypes.get(STRING) },
                "page":     { name: "page",     'type: builtInTypes.get(INT) }
            }
        ],
        ["input_fields_description", "SearchInput",
            {
                "keyword": { name: "keyword",   'type: builtInTypes.get(STRING),    description: "Keywords by client" }
            }
        ],
        ["input_fields_default_value", "SearchInput",
            {
                "keyword":  { name: "keyword",  'type: builtInTypes.get(STRING),    defaultValue: "Hello world" },
                "page":     { name: "page",     'type: builtInTypes.get(INT),       defaultValue: 0 },
                "average":  { name: "average",  'type: builtInTypes.get(FLOAT),     defaultValue: 5.5 },
                "repeat":   { name: "repeat",   'type: builtInTypes.get(BOOLEAN),   defaultValue: false }
            }
        ],
        ["input_fields_applied_directives", "SearchInput",
            {
                "keyword": { name: "keyword",   'type: builtInTypes.get(STRING),    appliedDirectives: [ 
                    {
                        args: {
                            [REASON_FIELD]: { value: REASON_FIELD_DEFAULT_VALUE, definition: builtInTypes.get(STRING) }
                        },
                        definition: builtInDirectives.get(DEPRECATED_DIR)
                    }
                ]}
            }
        ]
    ];
}
