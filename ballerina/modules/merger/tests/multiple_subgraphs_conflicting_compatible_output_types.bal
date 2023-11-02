import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "output_types", "compatible", "bel"],
    dataProvider: dataProviderConflictCompatibleOutputTypes
}
function testConflictCompatibleOutputTypes(string fieldName) returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_compatible_output_types");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;

    if actualFields !is () && expectedFields !is () {
        test:assertEquals(
            actualFields.get(fieldName).'type,
            expectedFields.get(fieldName).'type
        );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}

function dataProviderConflictCompatibleOutputTypes() returns [string][] {
    return [
        [ "same_named_type" ],
        [ "same_non_nullable_type" ],
        [ "same_list_type" ],
        [ "same_multi_list_type" ],
        [ "same_multi_wrapping_type" ],
        [ "same_multi_outer_inner_wrapping_type" ],
        [ "diff_non_nullable_type_1" ],
        [ "diff_non_nullable_type_2" ],
        [ "diff_outer_non_nullable_type" ],
        [ "diff_inner_non_nullable_type" ],
        [ "diff_outer_inner_non_nullable_type" ],
        [ "diff_outer_inner_diff_non_nullable_type" ],
        [ "diff_outer_inner_diff_wrapping_type" ],
        [ "interface_implements" ],
        [ "union_member" ]
    ];
}