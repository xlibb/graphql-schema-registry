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
    groups: ["custom", "directives"],
    dataProvider: dataProviderDirective
}
function testDirective(string fileName, __Directive expectedDirective) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
}

function dataProviderDirective() returns map<[string, __Directive]> {
    return {
        "1": ["directives_multiple_locations", 
                {
                    name: "customDirective",
                    locations: [ QUERY, MUTATION, SUBSCRIPTION, FIELD, FRAGMENT_DEFINITION,
                                 FRAGMENT_SPREAD, INLINE_FRAGMENT, VARIABLE_DEFINITION, SCHEMA, SCALAR,
                                 OBJECT, FIELD_DEFINITION, ARGUMENT_DEFINITION, INTERFACE, UNION,
                                 ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION ],
                    isRepeatable: false,
                    args: {}
                }
            ],
        "2": ["directives_repeatable", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: true,
                    args: {}
                }
            ],
        "3": ["directives_description", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: false,
                    args: {},
                    description: "Custom directive description"
                }
            ],
        "4": ["directives_arguments", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: false,
                    args: {
                        "arg": {
                            name: "arg",
                            appliedDirectives: [],
                            'type: builtInTypes.get(STRING)
                        },
                        "repeat": {
                            name: "repeat",
                            appliedDirectives: [],
                            'type: builtInTypes.get(BOOLEAN)
                        }
                    }
                }
            ]
    };
}
