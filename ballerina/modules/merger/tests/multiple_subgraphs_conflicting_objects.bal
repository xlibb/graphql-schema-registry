import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "objects", "conflict"]
}
function testConflictObjectTypeDescription() returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_objects");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals( supergraph.schema.types.get(typeName).name, schemas[0].types.get(typeName).name);
    test:assertEquals( supergraph.schema.types.get(typeName).description, schemas[0].types.get(typeName).description);
}

@test:Config {
    groups: ["merger", "objects", "bel"],
    dataProvider: dataProviderConflictObjectTypesFields
}
function testConflictObjectTypeFields(string fieldName) returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_objects");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(
            actualFields.get(fieldName).description,
            expectedFields.get(fieldName).description
        );
        test:assertEquals(
            actualFields.get(fieldName).appliedDirectives,
            expectedFields.get(fieldName).appliedDirectives
        );
    } else {
        test:assertFail(string `Cannot find field on '${typeName}' '${fieldName}'`);
    }
}

function dataProviderConflictObjectTypesFields() returns [string][] {
    return [
        ["name"],
        ["age"],
        ["avg"],
        ["isStudent"],
        ["isBux"]
    ];
}

@test:Config {
    groups: ["merger", "objects", "conflict", "hel"]
}
function testConflictInputType() returns error? {
    string typeName = "Bar";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_objects");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;

    string argName = "name";
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(actualFields.get(argName).args, expectedFields.get(argName).args);
    } else {
        test:assertFail(string `Fields of Object type cannot be ()`);
    }
}