import ballerina/test;

@test:Config {
    groups: ["merger", "federation"],
    dataProvider: dataProviderIsFederationSubgraph
}
function testIsFederationSubgraph(Subgraph subgraph, boolean expected) returns error? {
    test:assertEquals(subgraph.isSubgraph, expected);
}

function dataProviderIsFederationSubgraph() returns [Subgraph, boolean][]|error {
    Subgraph[] subgraphs = check getSubgraphsFromFileName("is_federation_subgraph", "subg");
    foreach Subgraph subgraph in subgraphs {
        subgraph.isSubgraph = check isFederation2Subgraph(subgraph);
    }

    return [
        [subgraphs[0], true],
        [subgraphs[1], false],
        [subgraphs[2], false],
        [subgraphs[3], false],
        [subgraphs[4], true]
    ];
}