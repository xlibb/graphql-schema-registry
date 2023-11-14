import ballerina/test;

@test:Config {
    groups: ["custom", "directives"],
    dataProvider: dataProviderDirective
}
function testDirective(string fileName, __Directive expectedDirective) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
 }

 function dataProviderDirective() returns map<[string, __Directive]> {
    return {
        "1": ["directives_multiple_locations", 
                {
                    name: "customDirective",
                    locations: [ QUERY, MUTATION, SUBSCRIPTION, FIELD, FRAGMENT_DEFINITION,
                                 FRAGMENT_SPREAD, INLINE_FRAGMENT, VARIABLE_DEFINITION, SCHEMA, SCALAR,
                                 OBJECT, FIELD_DEFINITION, ARGUMENT_DEFINITION, INTERFACE, UNION,
                                 ENUM, ENUM_VALUE, INPUT_OBJECT, INPUT_FIELD_DEFINITION ],
                    isRepeatable: false,
                    args: {}
                }
            ],
        "2": ["directives_repeatable", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: true,
                    args: {}
                }
            ],
        "3": ["directives_description", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: false,
                    args: {},
                    description: "Custom directive description"
                }
            ],
        "4": ["directives_arguments", 
                {
                    name: "customDirective",
                    locations: [ FIELD_DEFINITION, OBJECT ],
                    isRepeatable: false,
                    args: {
                        "arg": {
                            name: "arg",
                            appliedDirectives: [],
                            'type: gql_String
                        },
                        "repeat": {
                            name: "repeat",
                            appliedDirectives: [],
                            'type: gql_Boolean
                        }
                    }
                }
            ]
    };
 }