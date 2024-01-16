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
    groups: ["custom", "types", "interface"]
}
function testCustomInterfaceTypes() returns error? { 
    string sdl = check getGraphqlSdlFromFile("interface_types");
    __Type personInterface = {
        kind: INTERFACE,
        name: "Person",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [],
        possibleTypes: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Person"], personInterface);
}

@test:Config {
    groups: ["custom", "types", "interface"]
}
function testCustomInterfaceTypesDescription() returns error? { 
    string sdl = check getGraphqlSdlFromFile("interface_types_description");
    __Type personInterface = {
        kind: INTERFACE,
        name: "Person",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        description: "This is a person interface",
        interfaces: [],
        possibleTypes: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Person"], personInterface);
}

@test:Config {
    groups: ["custom", "types", "interface"]
}
function testCustomInterfaceTypesInterfaceImplementations() returns error? { 
    string sdl = check getGraphqlSdlFromFile("interface_types_interface_implementations");
    __Type personInterface = {
        kind: INTERFACE,
        name: "Person",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type citizenInterface = {
        kind: INTERFACE,
        name: "Citizen",
        fields: {
            "id": { name: "id", args: {}, 'type: builtInTypes.get(ID) }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type workerInterface = {
        kind: INTERFACE,
        name: "Worker",
        fields: {
            "id":   { name: "id",   args: {}, 'type: builtInTypes.get(ID) },
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [ citizenInterface, personInterface ],
        possibleTypes: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Worker"], workerInterface);
}

@test:Config {
    groups: ["custom", "types", "interface"]
}
function testCustomInterfaceTypeAppliedDirective() returns error? { 
    string sdl = check getGraphqlSdlFromFile("interface_types_applied_directives");
    __Directive testDirective = {
        name: "testDirective",
        args: {},
        locations: [ INTERFACE ],
        isRepeatable: false
    };
    __Type personInterface = {
        kind: INTERFACE,
        name: "Person",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [],
        possibleTypes: [],
        appliedDirectives: [ 
            {
                args: {},
                definition: testDirective
            }
        ]
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Person"], personInterface);
}
