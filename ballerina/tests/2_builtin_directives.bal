import ballerina/test;

@test:Config {
    groups: ["builtin", "directives"],
    dataProvider:  dataProviderBuiltInDirectives
}
function testBuiltInDirectives(string scalarName, __Directive expectedDirective) returns error? {
    string sdl = string `
        type Query {
            string: String
        }
    `;
    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.directives.get(scalarName), expectedDirective);
}

function dataProviderBuiltInDirectives() returns map<[string, __Directive]> {
    return { 
        "deprecated"  : ["deprecated", deprecated],
        "skip"        : ["skip", skip],
        "include"     : ["include", include],
        "specifiedBy" : ["specifiedBy", specifiedBy]
    };
}