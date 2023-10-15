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
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [],
        possibleTypes: []
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        description: "This is a person interface",
        interfaces: [],
        possibleTypes: []
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type citizenInterface = {
        kind: INTERFACE,
        name: "Citizen",
        fields: {
            "id": { name: "id", args: {}, 'type: gql_ID }
        },
        interfaces: [],
        possibleTypes: []
    };
    __Type workerInterface = {
        kind: INTERFACE,
        name: "Worker",
        fields: {
            "id": { name: "id", args: {}, 'type: gql_ID },
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [ citizenInterface, personInterface ],
        possibleTypes: []
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
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
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: [],
        possibleTypes: [],
        appliedDirectives: {
            "testDirective": {
                args: {},
                definition: testDirective
            }
        }
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types["Person"], personInterface);
 }