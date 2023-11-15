import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "interfaces", "conflict"],
    dataProvider: dataProviderConflictInterfaceTypesFields
}
function testConflictInterfaceTypeFields(TestSchemas schemas, string typeName, string fieldName) returns error? {
    map<parser:__Field>? actualFields = schemas.merged.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas.parsed.types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(
            actualFields.get(fieldName),
            expectedFields.get(fieldName)
        );
    } else {
        test:assertFail(string `Cannot find field on '${typeName}' '${fieldName}'`);
    }
}

function dataProviderConflictInterfaceTypesFields() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_compatible_interfaces");

    return [
        [ schemas, typeName, "name" ],
        [ schemas, typeName, "age" ],
        [ schemas, typeName, "avg" ],
        [ schemas, typeName, "isStudent" ],
        [ schemas, typeName, "isBux" ]
    ];
}