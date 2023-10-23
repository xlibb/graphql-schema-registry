import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "objects", "no-conflict"],
    dataProvider: dataProviderNoConflictObjectTypes
}
function testNoConflictObjectType(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_nonconflicting_objects");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals( supergraph.schema.types.get(typeName), schemas[0].types.get(typeName));
}

function dataProviderNoConflictObjectTypes() returns [string][] {
    return [
        ["Baz"],
        ["Foo"],
        ["Qux"],
        ["Bar"]
    ];
}

