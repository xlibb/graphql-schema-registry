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
    groups: ["custom", "types", "object"]
}
function testCustomObjectTypes() returns error? { 
    string sdl = check getGraphqlSdlFromFile("object_types");
    __Type addressType = {
        kind: OBJECT,
        name: "Address",
        fields: {
            "town": { name: "town", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: []
    };
    __Type personType = {
        kind: OBJECT,
        name: "Person",
        fields: {
            "id":       { name: "id",       args: {}, 'type: builtInTypes.get(ID) },
            "address":  { name: "address",  args: {}, 'type: addressType }
        },
        interfaces: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Address"], addressType);
    test:assertEquals(parsedSchema.types["Person"], personType);
 }

@test:Config {
    groups: ["custom", "types", "object"]
}
function testCustomObjectTypesDescription() returns error? { 
    string sdl = check getGraphqlSdlFromFile("object_types_description");
    __Type personType = {
        kind: OBJECT,
        name: "Person",
        fields: {
            "id":   { name: "id",   args: {}, 'type: builtInTypes.get(ID),      description: "This is the person's ID" },
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING),  description: "This is the person's name" }
        },
        interfaces: [],
        description: "This represents a Person"
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Person"], personType);
 }

@test:Config {
    groups: ["custom", "types", "object"]
}
function testCustomObjectTypeInterfaceImplementations() returns error? { 
    string sdl = check getGraphqlSdlFromFile("object_types_interface_implementations");
    __Type personInterface = {
        kind: INTERFACE,
        name: "Person",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type workerInterface = {
        kind: INTERFACE,
        name: "Worker",
        fields: {
            "salary": { name: "salary", args: {}, 'type: builtInTypes.get(FLOAT) }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type studentType = {
        kind: OBJECT,
        name: "Student",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: [ personInterface ]
    };
    __Type teacherType = {
        kind: OBJECT,
        name: "Teacher",
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) },
            "salary": { name: "salary", args: {}, 'type: builtInTypes.get(FLOAT) }
        },
        interfaces: [ personInterface, workerInterface ]
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Student"], studentType);
    test:assertEquals(parsedSchema.types["Teacher"], teacherType);
 }

@test:Config {
    groups: ["custom", "types", "object"]
}
function testCustomObjectTypeAppliedDirective() returns error? { 
    string sdl = check getGraphqlSdlFromFile("object_types_applied_directives");
    __Directive testDirective = {
        name: "testDirective",
        args: {},
        locations: [ OBJECT ],
        isRepeatable: false
    };
    __Type personType = {
        kind: OBJECT,
        name: "Person",
        fields: {
            "id": { name: "id", args: {}, 'type: builtInTypes.get(ID) }
        },
        interfaces: [],
        appliedDirectives: [ 
            {
                args: {},
                definition: testDirective
            }
        ]
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Person"], personType);
 }