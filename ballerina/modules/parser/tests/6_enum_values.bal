import ballerina/test;

@test:Config {
    groups: ["custom", "enum_values"],
    dataProvider: dataProviderEnumValues
}
function testEnumValues(string fileName, string typeName, __EnumValue[] expectedEnumValues) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types.get(typeName).enumValues, expectedEnumValues);
 }

 function dataProviderEnumValues() returns [string, string, __EnumValue[]][] {
    return [ 
        ["enum_values", "Status",
            [ { name: "ON_HOLD" }, { name: "COMPLETED" }, { name: "FAILED" } ]
        ],
        ["enum_values_description", "Status",
            [ { name: "ON_HOLD", description: "Project is on hold" } ]
        ],
        ["enum_values_applied_directive", "Status",
            [{ name: "ON_HOLD", appliedDirectives: [ 
                {
                    args: {
                        "reason": { value: "Added PAUSED", definition: builtInTypes.get(STRING) }
                    },
                    definition: builtInDirectives.get(DEPRECATED_DIR)
                }
            ],
                isDeprecated: true,
                deprecationReason: "Added PAUSED"
            }]
        ]
     ];
 }