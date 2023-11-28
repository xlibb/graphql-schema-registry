import ballerina/test;

@test:Config {
    groups: ["merger", "negative"],
    dataProvider: dataProviderNegativeTest
}
function testNegative(string testname) returns error? {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(testname, "subg");
    SupergraphMergeResult|MergeError[] merged = check (check new Merger(subgraphs)).merge();
    if merged is MergeError[] {
        string[] expectedErrorMessages = check getExpectedErrorMessages(testname);
        string[] actualErrorMessages = merged.map(e => e.message());

        test:assertEquals(actualErrorMessages, expectedErrorMessages);
    }
}

function dataProviderNegativeTest() returns [string][] {
    return [
        ["negative_type_mismatch"],
        ["negative_output_type_ref_mismatch"]
        // ["negative_invalid_field_sharing"
    ];
}