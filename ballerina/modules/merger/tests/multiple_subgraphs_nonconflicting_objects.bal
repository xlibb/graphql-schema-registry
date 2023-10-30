import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "objects", "no-conflict", "bel"],
    dataProvider: dataProviderNoConflictObjectTypes
}
function testNoConflictObjectType(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_nonconflicting_objects");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;

    if actualFields !is () && expectedFields !is () {
        test:assertEquals(actualFields.get("qux").'type.appliedDirectives, expectedFields.get("qux").'type.appliedDirectives);
    }

}

function dataProviderNoConflictObjectTypes() returns [string][] {
    return [
        ["Baz"]
    ];
}

