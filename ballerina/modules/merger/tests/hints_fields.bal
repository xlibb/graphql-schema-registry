import ballerina/test;

@test:Config {
    groups: ["merger", "hints"],
    dataProvider: dataProviderHintTest
}
function testHints(string testname) returns error? {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(testname, "subg");
    SupergraphMergeResult|MergeError[] merged = check (check new Merger(subgraphs)).merge();
    if merged is SupergraphMergeResult {
        string[] expectedHintMessages = check getExpectedHintMessages(testname);
        string[] actualHintMessages = printHints(merged.hints);

        test:assertEquals(actualHintMessages, expectedHintMessages);
    } else {
        test:assertFail("Supergraph composed without errors");
    }
}

function dataProviderHintTest() returns [string][] {
    return [
        ["hint_fields_inconsistent_field"]
    ];
}