import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "join__Graph"]
}
function testNoConflictJoinGraph() returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_join__Graph");
    
    test:assertEquals(
        schemas.merged.types.get(JOIN_GRAPH_TYPE),
        schemas.parsed.types.get(JOIN_GRAPH_TYPE)
    );
}