import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "enums", "conflict"],
    dataProvider:  dataProviderConflictEnumTypes
}
function testConflictEnumTypes(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_enum_types");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals( supergraph.schema.types.get(typeName).enumValues, schemas[0].types.get(typeName).enumValues);
}

function dataProviderConflictEnumTypes() returns [string][] {
    return [
        ["Foo"],
        ["Waldo"],
        ["Bar"],
        ["Thud"]
    ];
}