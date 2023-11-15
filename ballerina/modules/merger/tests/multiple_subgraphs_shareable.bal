import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "shareable"],
    dataProvider:  dataProviderShareableDirective
}
function testShareableDirective(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}

function dataProviderShareableDirective() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_shareable");

    return [
        [schemas, "Foo"],
        [schemas, "Waldo"]
    ];
}