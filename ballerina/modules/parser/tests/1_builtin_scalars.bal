import ballerina/test;

@test:Config {
    groups: ["builtin", "scalars"],
    dataProvider:  dataProviderBuiltInScalars
}
function testBuiltInScalars(string scalarName, __Type expectedScalar) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types.get(scalarName), expectedScalar);
}

function dataProviderBuiltInScalars() returns map<[string, __Type]> {
    return { 
        "Boolean": ["Boolean", Boolean],
        "String" : ["String", String],
        "Float"  : ["Float", Float],
        "Int"    : ["Int", Int],
        "ID"     : ["ID", ID]
    };
}