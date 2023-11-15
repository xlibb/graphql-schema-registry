import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "enums", "conflict"],
    dataProvider:  dataProviderConflictEnumTypes
}
function testConflictEnumTypes(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(schemas.merged.types.get(typeName).enumValues, schemas.parsed.types.get(typeName).enumValues);
}

function dataProviderConflictEnumTypes() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_enum_types");

    return [
        [ schemas, "Foo" ],
        [ schemas, "Waldo" ],
        [ schemas, "Bar" ],
        [ schemas, "Thud" ]
    ];
}