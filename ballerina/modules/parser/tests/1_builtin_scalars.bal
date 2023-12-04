import ballerina/test;

@test:Config {
    groups: ["builtin", "scalars"],
    dataProvider:  dataProviderBuiltInScalars
}
function testBuiltInScalars(string scalarName, __Type expectedScalar) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types.get(scalarName), expectedScalar);
}

function dataProviderBuiltInScalars() returns map<[string, __Type]> {
    return { 
        "Boolean": ["Boolean", gql_Boolean],
        "String" : ["String", gql_String],
        "Float"  : ["Float", gql_Float],
        "Int"    : ["Int", gql_Int],
        "ID"     : ["ID", gql_ID]
    };
}