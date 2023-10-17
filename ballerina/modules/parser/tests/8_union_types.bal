import ballerina/test;

__Type dogType = {
    kind: OBJECT,
    name: "Dog",
    fields: {
        "name": { name: "name", args: {}, 'type: gql_String }
    },
    interfaces: []
};
__Type catType = {
    kind: OBJECT,
    name: "Cat",
    fields: {
        "name": { name: "name", args: {}, 'type: gql_String }
    },
    interfaces: []
};

@test:Config {
    groups: ["custom", "types", "union"],
    dataProvider: dataProviderUnion
}
function testCustomUnionTypes(string fileName, __Type expectedUnionType) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);
    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    string? unionTypeName = expectedUnionType.name;
    if (unionTypeName != ()) {
        test:assertEquals(parsedSchema.types.get(unionTypeName), expectedUnionType);
    } else {
        test:assertFail("No Union type found");
    }
 }

function dataProviderUnion() returns map<[string, __Type]> {
    return {
        "1": [
            "union_types", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ]
            }
        ],
        "2": [
            "union_types_description", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ],
                description: "This is a union description"
            }
        ],
        "3": [
            "union_types_applied_directive", {
                kind: UNION,
                name: "Pet",
                possibleTypes: [ catType, dogType ],
                appliedDirectives: [ 
                    {
                        args: {},
                        definition: {
                            name: "testDirective",
                            locations: [ UNION ],
                            args: {},
                            isRepeatable: false
                        }
                    }
                ]
            }
        ]
    };
}