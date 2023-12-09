import ballerina/test;

@test:Config {
    groups: ["merger", "federation"],
    dataProvider: dataProviderIsFederationSubgraph
}
function testIsFederationSubgraph(Subgraph subgraph, boolean|error expected) returns error? {
    error|boolean isFederation2SubgraphResult = isFederation2Subgraph(subgraph);
    if isFederation2SubgraphResult is boolean && expected is boolean {
        test:assertEquals(isFederation2SubgraphResult, expected);
    } else if isFederation2SubgraphResult is error && expected is error {
        test:assertEquals(isFederation2SubgraphResult.message(), expected.message());
    } else {
        test:assertFail("Type mismatch");
    }
}

function dataProviderIsFederationSubgraph() returns [Subgraph, boolean|error][]|error {
    Subgraph[] subgraphs = check getSubgraphsFromFileName("is_federation_subgraph", "subg");

    return [
        [subgraphs[0], true],
        [subgraphs[1], false],
        [subgraphs[2], error InvalidFederationSpec("Unsupported Federation version 'v2.3'")],
        [subgraphs[3], false],
        [subgraphs[4], true]
    ];
}