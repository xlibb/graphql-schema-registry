import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "objects", "no-conflict"],
    dataProvider: dataProviderNoConflictTypes
}
function testNoConflictTypes(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}

function dataProviderNoConflictTypes() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_nonconflicting_types");

    return [
        [schemas, "Bar"],
        [schemas, "Qux"],
        [schemas, "Waldo"],
        [schemas, "Bux"],
        [schemas, "Baz"]
    ];
}

