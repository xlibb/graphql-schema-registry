import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "interfaces"],
    dataProvider: dataProviderConflictInterfaceImplements
}
function testConflictInterfaceImplements(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(schemas.merged.types.get(typeName).appliedDirectives, schemas.parsed.types.get(typeName).appliedDirectives);
    test:assertEquals(schemas.merged.types.get(typeName).interfaces, schemas.parsed.types.get(typeName).interfaces);
}

function dataProviderConflictInterfaceImplements() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_interface_implements");

    return [
        [ schemas, "Foo" ]
    ];
}