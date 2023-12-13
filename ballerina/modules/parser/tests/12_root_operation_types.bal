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
            "name": { 
                name: "name",
                args: {}, 
                'type: builtInTypes.get(STRING) 
            }
        },
        interfaces: []
    };
    __Type mutationType = {
        kind: OBJECT,
        name: "Mutation",
        fields: {
            "number": { 
                name: "number",
                args: { 
                    "page": { 
                        name: "page", 
                        'type: builtInTypes.get(INT) 
                    }
                },
                'type: builtInTypes.get(FLOAT) 
            }
        },
        interfaces: []
    };
    __Type subscriptionType = {
        kind: OBJECT,
        name: "Subscription",
        fields: {
            "name": { 
                name: "name",
                args: {}, 
                'type: builtInTypes.get(STRING) 
            }
        },
        interfaces: []
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types["Query"],          queryType);
    test:assertEquals(parsedSchema.queryType,               queryType);
    test:assertEquals(parsedSchema.types["Mutation"],       mutationType);
    test:assertEquals(parsedSchema.mutationType,            mutationType);
    test:assertEquals(parsedSchema.types["Subscription"],   subscriptionType);
    test:assertEquals(parsedSchema.subscriptionType,        subscriptionType);
 }