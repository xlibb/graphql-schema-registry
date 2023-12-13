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

function dataProviderWrappingTypes() returns [string, string, __Type][] {
    return [ 
        [
            "wrapping_types_list",
            "list", 
            wrapType(builtInTypes.get(STRING), LIST)
        ],
        [
            "wrapping_types_nonnull",
            "nonnull",
            wrapType(builtInTypes.get(STRING), NON_NULL)
        ],
        [
            "wrapping_types_list_of_nonnull",
            "list_of_nonnull",
            wrapType(wrapType(builtInTypes.get(STRING), NON_NULL), LIST)
        ],
        [
            "wrapping_types_nonnull_list_of_nonnull",
            "nonnull_list_of_nonnull",
            wrapType(wrapType(wrapType(builtInTypes.get(STRING), NON_NULL), LIST), NON_NULL)
        ],
        [
            "wrapping_types_list_of_list_of_list",
            "list_of_list_of_list",
            wrapType(wrapType(wrapType(builtInTypes.get(STRING), LIST), LIST), LIST)
        ]
     ];
}