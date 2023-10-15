import ballerina/test;

@test:Config {
    groups: ["custom", "input_fields"],
    dataProvider: dataProviderInputFields
}
function testInputField(string fileName, string inputTypeName, map<__InputValue> inputFields) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types.get(inputTypeName).inputFields, inputFields);
 }

 function dataProviderInputFields() returns map<[string, string, map<__InputValue>]> {
    return {
        "1": ["input_fields", "SearchInput",
                {
                    "keyword": { name: "keyword", 'type: gql_String },
                    "page": { name: "page", 'type: gql_Int }
                }
            ],
        "2": ["input_fields_description", "SearchInput",
                {
                    "keyword": { name: "keyword", 'type: gql_String, description: "Keywords by client" }
                }
            ],
        "3": ["input_fields_default_value", "SearchInput",
                {
                    "keyword": { name: "keyword", 'type: gql_String, defaultValue: "Hello world" },
                    "page": { name: "page", 'type: gql_Int, defaultValue: 0 },
                    "average": { name: "average", 'type: gql_Float, defaultValue: 5.5 },
                    "repeat": { name: "repeat", 'type: gql_Boolean, defaultValue: false }
                }
            ],
        "4": ["input_fields_applied_directives", "SearchInput",
                {
                    "keyword": { name: "keyword", 'type: gql_String, appliedDirectives: {
                        "deprecated": {
                            args: {
                                "reason": { value: "No longer supported", definition: gql_String }
                            },
                            definition: deprecated
                        }
                    }}
                }
            ]
    };
 }