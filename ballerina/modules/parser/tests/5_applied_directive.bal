import ballerina/test;

@test:Config {
    groups: ["builtin", "applied_directives"],
    dataProvider: dataProviderAppliedDirective
}
function testAppliedDirective(string fileName, string fieldName, map<__AppliedDirective> expectedAppliedDirectives) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    map<__Field>? fields = parsedSchema.queryType.fields;
    if (fields != ()) {
        map<__AppliedDirective>? appliedDirectives = fields.get(fieldName).appliedDirectives;
        test:assertEquals(appliedDirectives, expectedAppliedDirectives);
    } else {
        test:assertFail("No fields on Query");
    }
 }

 function dataProviderAppliedDirective() returns map<[string, string, map<__AppliedDirective>]> {
    return {
        "1": ["applied_directive", "name", 
                {
                    "deprecated": {
                        args: {
                            "reason": {
                                value: "This field is deprecated",
                                definition: gql_String
                            }
                        },
                        definition: deprecated
                    }
                }
        ],
        "2": ["applied_directive_default_value", "name", 
                {
                    "deprecated": {
                        args: {
                            "reason": {
                                value: "No longer supported",
                                definition: gql_String
                            }
                        },
                        definition: deprecated
                    }
                }
        ]                                                    
    };
 }