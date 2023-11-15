import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "directives", "filter"],
    dataProvider: dataProviderDirectiveDefinitionPresence
}
function testDirectiveDefinitionPresence(TestSchemas schemas, string directiveName) {
    test:assertEquals(
        schemas.merged.directives.hasKey(directiveName), 
        schemas.parsed.directives.hasKey(directiveName)
    );
    if (schemas.merged.directives.hasKey(directiveName) && schemas.parsed.directives.hasKey(directiveName)) {
        test:assertEquals(
            schemas.merged.directives.get(directiveName),
            schemas.parsed.directives.get(directiveName)
        );
    }
}

function dataProviderDirectiveDefinitionPresence() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("directive_definition_presence");

    return [
        [ schemas, "foo" ],
        [ schemas, "executableFoo" ]
    ];
}