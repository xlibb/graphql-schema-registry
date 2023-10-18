import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "federation", "types", "single"],
    dataProvider: dataProviderFederationSupergraphTypes
}
function testSupergraphFederationTypes(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("supergraph_definitions");
    parser:__Schema supergraph = check merge(schemas[1]);

    if (schemas[0].types.hasKey(typeName) && supergraph.types.hasKey(typeName)) {
        test:assertEquals(supergraph.types[typeName], schemas[0].types[typeName]);
    } else {
        test:assertFail(string `Could not find '${typeName}'`);
    }
}

function dataProviderFederationSupergraphTypes() returns [string][] {
    return [
        [JOIN_FIELDSET_TYPE],
        [LINK_IMPORT_TYPE],
        [LINK_PURPOSE_TYPE],
        [JOIN_GRAPH_TYPE]
    ];
}

@test:Config {
    groups: ["merger", "federation", "directives", "nonconflicting"],
    dataProvider: dataProviderSupergraphFederationDirectives
}
function testSupergraphFederationDirectives(string directiveName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("supergraph_definitions");
    parser:__Schema supergraph = check merge(schemas[1]);

    if (schemas[0].directives.hasKey(directiveName) && supergraph.directives.hasKey(directiveName)) {
        test:assertEquals(schemas[0].directives[directiveName], supergraph.directives[directiveName]);
    } else {
        test:assertFail(string `Could not find '${directiveName}'`);
    }
}

function dataProviderSupergraphFederationDirectives() returns [string][] {
    return [
        [LINK_DIR],
        [JOIN_GRAPH_DIR],
        [JOIN_UNION_MEMBER_DIR],
        [JOIN_ENUMVALUE_DIR],
        [JOIN_FIELD_DIR],
        [JOIN_IMPLEMENTS_DIR],
        [JOIN_TYPE_DIR]
    ];
}