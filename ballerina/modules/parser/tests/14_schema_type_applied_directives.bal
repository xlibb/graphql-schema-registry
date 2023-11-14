import ballerina/test;

@test:Config {
    groups: ["builtin"]
}
function testSchemaTypeAppliedDirectives() returns error? {
    string sdl = check getGraphqlSdlFromFile("schema_type_applied_directives");
    Parser parser = new(sdl, SUBGRAPH_SCHEMA);
    __Schema parsedSchema = check parser.parse();

    __Directive fooDirective = {
        name: "foo",
        locations: [ SCHEMA ],
        args: {},
        isRepeatable: true
    };
    __AppliedDirective appliedFooDir = {
        args: {},
        definition: fooDirective
    };
    __Type queryType = {
        kind: OBJECT,
        name: QUERY_TYPE,
        fields: {
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: []
    };
    __Type mutationType = {
        kind: OBJECT,
        name: MUTATION_TYPE,
        fields: {
            "name": { name: "name", args: {}, 'type: gql_String }
        },
        interfaces: []
    };
    __Schema expectedSchema = {
        types: {
            [QUERY_TYPE]: queryType,
            [MUTATION_TYPE]: mutationType
        },
        directives: {
            "foo": fooDirective
        },
        queryType: queryType,
        mutationType: mutationType,
        appliedDirectives: [appliedFooDir]
    };

    test:assertEquals(parsedSchema.appliedDirectives, expectedSchema.appliedDirectives);
}