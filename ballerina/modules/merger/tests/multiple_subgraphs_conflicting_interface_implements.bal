import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "interfaces", "conflict"]
}
function testConflictInterfaceImplements() returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_interface_implements");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals( supergraph.schema.types.get(typeName).appliedDirectives, schemas[0].types.get(typeName).appliedDirectives);
    test:assertEquals( supergraph.schema.types.get(typeName).interfaces, schemas[0].types.get(typeName).interfaces);
}