import ballerina/test;
import graphql_schema_registry.exporter;

@test:Config {
    groups: ["merger", "example"],
    dataProvider: dataProviderSimpleRealworldExample
}
function testSimpleRealworldExample(TestSchemas schemas, string typeName) returns error? {
    test:assertEquals(
        schemas.merged.types.get(typeName),
        schemas.parsed.types.get(typeName)
    );
}

function dataProviderSimpleRealworldExample() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("simple_realworld_example");

    return [
        [schemas, "Product"],
        [schemas, "Review"],
        [schemas, "ReviewInput"],
        [schemas, "User"],
        [schemas, "Query"],
        [schemas, "Mutation"]
    ];
}

@test:Config {
    groups: ["merger", "example"]
}
function testSimpleRealworldExampleExportSDL() returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("simple_realworld_example");

    string exportedSdl = check (new exporter:Exporter(schemas.merged)).export();
    test:assertEquals(exportedSdl, check getSupergraphSdlFromFileName("simple_realworld_example"));
}