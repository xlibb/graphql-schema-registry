import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "compatible", "default_values"],
    dataProvider: dataProviderConflictCompatibleDefaultValues
}
function testConflictCompatibleDefaultValues(TestSchemas schemas, string typeName, string fieldName) {
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

function dataProviderConflictCompatibleDefaultValues() returns [TestSchemas, string, string][]|error {
    string typeName = "Foo";
    TestSchemas schemas = check getMergedAndParsedSchemas("multiple_subgraphs_conflicting_default_values");

    return [
        [ schemas, typeName, "name" ],
        [ schemas, typeName, "age" ]
    ];
}