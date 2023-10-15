import ballerina/test;

@test:Config {
    groups: ["custom", "enum_values"],
    dataProvider: dataProviderEnumValues
}
function testEnumValues(string fileName, string typeName, __EnumValue[] expectedEnumValues) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types.get(typeName).enumValues, expectedEnumValues);
 }

 function dataProviderEnumValues() returns map<[string, string, __EnumValue[]]> {
    return {
        "1": ["enum_values", "Status",
                [ { name: "ON_HOLD" }, { name: "COMPLETED" }, { name: "FAILED" } ]
            ],
        "2": ["enum_values_description", "Status",
                [ { name: "ON_HOLD", description: "Project is on hold" } ]
            ],
        "3": ["enum_values_applied_directive", "Status",
                [ { name: "ON_HOLD", appliedDirectives: {
                    "deprecated": {
                        args: {
                            "reason": { value: "Added PAUSED", definition: gql_String }
                        },
                        definition: deprecated
                    }
                 },
                    isDeprecated: true,
                    deprecationReason: "Added PAUSED"
                 } ]
            ]
    };
 }