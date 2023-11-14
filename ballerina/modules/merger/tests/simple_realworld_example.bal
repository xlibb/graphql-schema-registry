import ballerina/test;
import graphql_schema_registry.parser;
import graphql_schema_registry.exporter;

@test:Config {
    groups: ["merger", "example"],
    dataProvider: dataProviderSimpleRealworldExample
}
function testSimpleRealworldExample(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("simple_realworld_example");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals(
        supergraph.schema.types.get(typeName),
        schemas[0].types.get(typeName)
    );
}

function dataProviderSimpleRealworldExample() returns [string][] {
    return [
        ["Product"],
        ["Review"],
        ["ReviewInput"],
        ["User"],
        ["Query"],
        ["Mutation"]
    ];
}

@test:Config {
    groups: ["merger", "example"]
}
function testSimpleRealworldExampleExportSDL() returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("simple_realworld_example");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    string export = check (new exporter:Exporter(supergraph.schema)).export();
    test:assertEquals(export, check getSupergraphSdlFromFileName("simple_realworld_example"));
}