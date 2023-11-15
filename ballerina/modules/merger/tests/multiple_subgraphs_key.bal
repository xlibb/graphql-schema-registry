import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "key"]
}
function testKeyDirective() returns error? {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_key");

    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}