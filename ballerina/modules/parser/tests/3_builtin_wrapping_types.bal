import ballerina/test;

@test:Config {
    groups: ["builtin", "types", "wrapping"],
    dataProvider: dataProviderWrappingTypes
}
function testBuiltInWrappingTypes(string fileName, string fieldName, __Type expectedWrappingType) returns error? {
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    map<__Field>? fields = parsedSchema.queryType.fields;
    if (fields != ()) {
        test:assertEquals(fields.get(fieldName).'type, expectedWrappingType);
    }
}

function dataProviderWrappingTypes() returns map<[string, string, __Type]> {
    return { 
        "1" : ["wrapping_types_list", "list", wrapType(gql_String, LIST)],
        "2" : ["wrapping_types_nonnull", "nonnull", wrapType(gql_String, NON_NULL)],
        "3" : ["wrapping_types_list_of_nonnull", "list_of_nonnull", wrapType(wrapType(gql_String, NON_NULL), LIST)],
        "4" : ["wrapping_types_nonnull_list_of_nonnull", "nonnull_list_of_nonnull", wrapType(wrapType(wrapType(gql_String, NON_NULL), LIST), NON_NULL)],
        "5" : ["wrapping_types_list_of_list_of_list", "list_of_list_of_list", wrapType(wrapType(wrapType(gql_String, LIST), LIST), LIST)]
     };
}