import ballerina/test;

@test:Config {
    groups: ["differ"],
    dataProvider: dataProviderTestDiffer
}
function testDiffer(string testName) returns error? {
    var [newSchema, oldSchema] = check getSchemas(testName);
    SchemaDiff[] expectedDiffs = check getExpectedDiffs(testName);
    SchemaDiff[] actualDiffs = check diff(newSchema, oldSchema);

    test:assertEquals(actualDiffs, expectedDiffs);
}

function dataProviderTestDiffer() returns [string][] {
    return [
        ["type_removals_additions"],
        ["directive_removals_additions"],
        ["type_kind_changes"],
        ["type_description_change"],
        ["field_removals_additions"],
        ["field_descriptions"],
        ["field_deprecations"],
        ["field_types"],
        ["interface_implements"],
        ["field_arguments_types"],
        ["field_arguments_removals_additions"],
        ["field_arguments_descriptions"],
        ["field_arguments_default_values"],
        ["enum_values"],
        ["union_possible_types"],
        ["directive_descriptions"],
        ["directive_arguments_types"],
        ["directive_arguments_removals_additions"],
        ["directive_arguments_default_values"],
        ["directive_arguments_descriptions"]
    ];
}