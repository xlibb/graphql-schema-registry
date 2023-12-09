import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "key"],
    dataProvider: dataProviderKeyDirective
}
function testKeyDirective(string typeName) returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_key");

    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}

function dataProviderKeyDirective() returns [string][] {
    return [
        ["Foo"],
        ["Fox"]
    ];
}