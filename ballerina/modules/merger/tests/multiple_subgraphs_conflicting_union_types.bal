import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "union_types", "conflict"]
}
function testConflictUnionTypes() returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_union_types");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    foreach parser:__AppliedDirective expectedAppliedDirective in schemas[0].types.get(typeName).appliedDirectives {
        test:assertTrue(supergraph.schema.types.get(typeName).appliedDirectives
                                                             .some(a => a == expectedAppliedDirective)
        );
    }

    parser:__Type[]? actualPossibleTypes = supergraph.schema.types.get(typeName).possibleTypes;
    parser:__Type[]? expectedPossibleTypes = schemas[0].types.get(typeName).possibleTypes;

    if actualPossibleTypes !is () && expectedPossibleTypes !is () {
        test:assertEquals( actualPossibleTypes, expectedPossibleTypes );
    } else {
        test:assertFail("actual/expected fields are null");
    }
}