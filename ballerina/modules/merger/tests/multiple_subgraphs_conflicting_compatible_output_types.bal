import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "output_types"],
    dataProvider: dataProviderConflictCompatibleOutputTypes
}
function testConflictCompatibleOutputTypes(TestSchemas schemas, string typeName, string fieldName) {
    map<parser:__Field>? actualFields = schemas.merged.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas.parsed.types.get(typeName).fields;

    if actualFields !is () && expectedFields !is () {
        test:assertTrue(
            assertOutputTypes(
                actualFields.get(fieldName).'type,
                expectedFields.get(fieldName).'type
            )
        );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}

function dataProviderConflictCompatibleOutputTypes() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_output_types");

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
        [ schemas, typeName, "diff_outer_inner_diff_wrapping_type" ],
        [ schemas, typeName, "interface_implements" ],
        [ schemas, typeName, "union_member" ]
    ];
}

function assertOutputTypes(parser:__Type typeA, parser:__Type typeB) returns boolean {
    parser:__Type? typeAWrappedType = typeA.ofType;
    parser:__Type? typeBWrappedType = typeB.ofType;

    if typeAWrappedType is () && typeBWrappedType is () {
        return typeA.name == typeB.name;
    } else if typeAWrappedType !is () && typeBWrappedType !is () {
        return assertOutputTypes(typeAWrappedType, typeBWrappedType);
    } 
    return false;
}