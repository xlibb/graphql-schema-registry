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
            "town": { name: "town", args: {}, 'type: gql_String }
        },
        interfaces: []
    };
    __Type personType = {
        kind: OBJECT,
        name: "Person",
        fields: {
            "id": { name: "id", args: {}, 'type: gql_ID },
            "address": { name: "address", args: {}, 'type: addressType }
        },
        interfaces: []
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "id": { name: "id", args: {}, 'type: gql_ID, description: "This is the person's ID" },
            "name": { name: "name", args: {}, 'type: gql_String, description: "This is the person's name" }
        },
        interfaces: [],
        description: "This represents a Person"
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type workerInterface = {
        kind: INTERFACE,
        name: "Worker",
        fields: {
            "salary": { name: "salary", args: {}, 'type: gql_Float }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type studentType = {
        kind: OBJECT,
        name: "Student",
        fields: {
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [ personInterface ]
    };
    __Type teacherType = {
        kind: OBJECT,
        name: "Teacher",
        fields: {
            "name": { name: "name", args: {}, 'type: gql_String },
            "salary": { name: "salary", args: {}, 'type: gql_Float }
        },
        interfaces: [ personInterface, workerInterface ]
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "id": { name: "id", args: {}, 'type: gql_ID }
        },
        interfaces: [],
        appliedDirectives: [ 
            {
                args: {},
                definition: testDirective
            }
        ]
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types["Person"], personType);
 }