import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "entity"]
}
function testKeyDirective() returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_key_directive");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals(
        supergraph.schema.types.get(typeName),
        schemas[0].types.get(typeName)
    );
}