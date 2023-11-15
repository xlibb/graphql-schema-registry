import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "descriptions"],
    dataProvider: dataProviderTypeDescriptions
}
function testTypeDescriptions(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(schemas.merged.types.get(typeName).description, schemas.parsed.types.get(typeName).description);
}

function dataProviderTypeDescriptions() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_types_description");

    return [
        [schemas, "Email"],
        [schemas, "Bux"],
        [schemas, "Bar"],
        [schemas, "Foo"],
        [schemas, "Waldo"]
    ];
}