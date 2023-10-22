import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "directives", "filter"],
    dataProvider: dataProviderDirectiveDefinitionPresence
}
function testDirectiveDefinitionPresence(string directiveName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("directive_definition_presence");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals(
        supergraph.schema.directives.hasKey(directiveName), 
        schemas[0].directives.hasKey(directiveName)
    );
    if (supergraph.schema.directives.hasKey(directiveName) && schemas[0].directives.hasKey(directiveName)) {
        test:assertEquals(
            supergraph.schema.directives.get(directiveName),
            schemas[0].directives.get(directiveName)
        );
    }
}

function dataProviderDirectiveDefinitionPresence() returns [string][] {
    return [
        ["foo"],
        ["executableFoo"]
    ];
}