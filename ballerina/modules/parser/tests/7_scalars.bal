import ballerina/test;

@test:Config {
    groups: ["custom", "types", "scalars"],
    dataProvider: dataProviderScalarValidation
}
function testCustomScalarTypes(string filename, __Type expectedScalarType) returns error? {
    string sdl = check getGraphqlSdlFromFile(filename);
    __Schema parsedSchema = check parseSdl(sdl);

    string? typeName = expectedScalarType.name;
    if (typeName != ()) {
        test:assertEquals(parsedSchema.types[typeName], expectedScalarType);
    }
}

function dataProviderScalarValidation() returns map<[string, __Type]> {
    return { 
        "1" : ["scalars", { kind: SCALAR, name: "Email", description: "" }],
        "2" : ["scalars_with_description", { kind: SCALAR, name: "Email", description: "Email description" }]
     };
}