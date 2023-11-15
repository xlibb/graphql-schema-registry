import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "objects", "conflict"],
    dataProvider: dataProviderConflictObjectTypesFields
}
function testConflictObjectTypeFields(TestSchemas schemas, string typeName, string fieldName) returns error? {
    map<parser:__Field>? actualFields = schemas.merged.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas.parsed.types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(
            actualFields.get(fieldName).'type,
            expectedFields.get(fieldName).'type
        );
    } else {
        test:assertFail(string `Cannot find field on '${typeName}' '${fieldName}'`);
    }
}

function dataProviderConflictObjectTypesFields() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_objects");

    return [
        [ schemas, typeName, "name" ],
        [ schemas, typeName, "age" ],
        [ schemas, typeName, "avg" ],
        [ schemas, typeName, "isStudent" ],
        [ schemas, typeName, "isBux" ]
    ];
}

@test:Config {
    groups: ["merger", "compatible", "objects", "conflict"],
    dataProvider: dataProviderConflictObjectFieldInputType
}
function testConflictObjectFieldInputType(TestSchemas schemas, string typeName, string fieldName) returns error? {
    map<parser:__Field>? actualFields = schemas.merged.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas.parsed.types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(actualFields.get(fieldName).args, expectedFields.get(fieldName).args);
    } else {
        test:assertFail(string `Fields of Object type cannot be ()`);
    }
}

function dataProviderConflictObjectFieldInputType() returns [TestSchemas, string, string][]|error {
    string typeName = "Bar";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_objects");

    return [
        [ schemas, typeName, "name" ]
    ];
}