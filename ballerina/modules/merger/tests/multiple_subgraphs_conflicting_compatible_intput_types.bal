import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "input_types"],
    dataProvider: dataProviderConflictCompatibleInputTypes
}
function testConflictCompatibleInputTypes(TestSchemas schemas, string typeName, string fieldName) {
    map<parser:__InputValue>? actualFields = schemas.merged.types.get(typeName).inputFields;
    map<parser:__InputValue>? expectedFields = schemas.parsed.types.get(typeName).inputFields;

    if actualFields !is () && expectedFields !is () {
        test:assertEquals(
            actualFields.get(fieldName),
            expectedFields.get(fieldName)
        );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}

function dataProviderConflictCompatibleInputTypes() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_input_types");

    return [
        [ schemas, typeName, "same_named_type" ],
        [ schemas, typeName, "same_non_nullable_type" ],
        [ schemas, typeName, "same_list_type" ],
        [ schemas, typeName, "same_multi_list_type" ],
        [ schemas, typeName, "same_multi_wrapping_type" ],
        [ schemas, typeName, "same_multi_outer_inner_wrapping_type" ],
        [ schemas, typeName, "diff_non_nullable_type_1" ],
        [ schemas, typeName, "diff_non_nullable_type_2" ],
        [ schemas, typeName, "diff_outer_non_nullable_type" ],
        [ schemas, typeName, "diff_inner_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_diff_non_nullable_type" ],
        [ schemas, typeName, "diff_outer_inner_diff_wrapping_type" ]
    ];
}