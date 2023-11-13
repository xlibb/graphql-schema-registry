import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "description", "conflict", "hints"]
}
function testConflictDescriptionHints() returns error? {
    string typeName = "Query";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_description_hints");
    MergeError|Supergraph|error supergraph = (new Merger(schemas[1])).merge();
    if supergraph is MergeError {
        printHints([supergraph.detail().hint]);
        return;
    }
    if supergraph is error {
        return supergraph;
    }

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(actualFields, expectedFields);
    } else {
        test:assertFail(string `Cannot find field on '${typeName}'`);
    }
}