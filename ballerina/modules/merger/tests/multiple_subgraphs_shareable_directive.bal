import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "shareable", "nol"],
    dataProvider:  dataProviderShareableDirective
}
function testShareableDirective(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_shareable_directive");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals(
        supergraph.schema.types.get(typeName),
        schemas[0].types.get(typeName)
    );
}

function dataProviderShareableDirective() returns [string][] {
    return [
        ["Foo"],
        ["Waldo"]
    ];
}