import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "union_types"]
}
function testConflictUnionTypesAppliedDirectives() returns error? {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_union_types");

    foreach parser:__AppliedDirective expectedAppliedDirective in schemas.parsed.types.get(typeName).appliedDirectives {
        test:assertTrue(schemas.merged.types.get(typeName).appliedDirectives
                                                             .some(a => a == expectedAppliedDirective)
        );
    }
}

@test:Config {
    groups: ["merger", "compatible", "union_types"]
}
function testConflictUnionTypesPossibleTypes() returns error? {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_union_types");

    parser:__Type[]? actualPossibleTypes = schemas.merged.types.get(typeName).possibleTypes;
    parser:__Type[]? expectedPossibleTypes = schemas.parsed.types.get(typeName).possibleTypes;

    if actualPossibleTypes !is () && expectedPossibleTypes !is () {
        test:assertEquals( actualPossibleTypes, expectedPossibleTypes );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}