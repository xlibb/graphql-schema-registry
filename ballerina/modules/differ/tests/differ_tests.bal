import ballerina/test;

@test:Config {
    groups: ["differ"],
    dataProvider: dataProviderTestDiffer
}
function testDiffer(string testName) returns error? {
    var [newSchema, oldSchema] = check getSchemas(testName);
    SchemaDiff[] expectedDiffs = check getExpectedDiffs(testName);
    SchemaDiff[] actualDiffs = getDiff(newSchema, oldSchema);

    test:assertEquals(actualDiffs, expectedDiffs);
}

function dataProviderTestDiffer() returns [string][] {
    return [
        ["type_removals_additions"],
        ["directive_removals_additions"],
        ["type_kind_changes"]
    ];
}