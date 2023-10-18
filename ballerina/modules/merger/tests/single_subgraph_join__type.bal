import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "join__type"],
    dataProvider: dataProviderSingleSimpleSubgraph
}
function testSingleSimpleSubgraphTypesShallow(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("single_subgraph_join__type");
    parser:__Schema supergraph = check merge(schemas[1]);

    test:assertEquals(supergraph.types.get(typeName).name, schemas[0].types.get(typeName).name);
    test:assertEquals(supergraph.types.get(typeName).description, schemas[0].types.get(typeName).description);
    test:assertEquals(
        supergraph.types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR), 
        schemas[0].types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR)
    );
}

function dataProviderSingleSimpleSubgraph() returns [string][] {
    return [
        ["SearchQuery"],
        ["Person"],
        ["Salary"],
        ["DegreeStatus"],
        ["Academic"],
        ["Student"],
        ["Teacher"],
        ["Query"]
    ];
}