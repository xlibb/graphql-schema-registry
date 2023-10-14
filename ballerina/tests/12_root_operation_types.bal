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
            "name": { name: "name", args: {}, 'type: String }
        },
        interfaces: []
    };
    __Type mutationType = {
        kind: OBJECT,
        name: "Mutation",
        fields: {
            "number": { name: "number", args: { "page": { name: "page", 'type: Int } }, 'type: Float }
        },
        interfaces: []
    };
    __Type subscriptionType = {
        kind: OBJECT,
        name: "Subscription",
        fields: {
            "name": { name: "name", args: {}, 'type: String }
        },
        interfaces: []
    };

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types["Query"], queryType);
    test:assertEquals(parsedSchema.queryType, queryType);
    test:assertEquals(parsedSchema.types["Mutation"], mutationType);
    test:assertEquals(parsedSchema.mutationType, mutationType);
    test:assertEquals(parsedSchema.types["Subscription"], subscriptionType);
    test:assertEquals(parsedSchema.subscriptionType, subscriptionType);
 }