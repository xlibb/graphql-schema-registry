import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "join__type", "no-conflict"],
    dataProvider: dataProviderNoConflictJoinType
}
function testNoConflictJoinType(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_join__type_and_join__Graph");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals(
        supergraph.schema.types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR), 
        schemas[0].types.get(typeName).appliedDirectives.filter(d => d.definition.name == JOIN_TYPE_DIR)
    );
}

function dataProviderNoConflictJoinType() returns [string][] {
    return [
        ["Email"],
        ["Salary"],
        ["Query"]
    ];
}

@test:Config {
    groups: ["merger", "join__Graph", "no-conflict"]
}
function testNoConflictJoinGraph() returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_join__type_and_join__Graph");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();
    
    test:assertEquals(
        supergraph.schema.types.get(JOIN_GRAPH_TYPE),
        schemas[0].types.get(JOIN_GRAPH_TYPE)
    );
}