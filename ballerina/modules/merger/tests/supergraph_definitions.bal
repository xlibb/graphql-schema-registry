import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "federation", "types", "single"],
    dataProvider: dataProviderFederationSupergraphTypes
}
function testSupergraphFederationTypes(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("supergraph_definitions");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    if (schemas[0].types.hasKey(typeName) && supergraph.schema.types.hasKey(typeName)) {
        test:assertEquals(supergraph.schema.types[typeName], schemas[0].types[typeName]);
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
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    if (schemas[0].directives.hasKey(directiveName) && supergraph.schema.directives.hasKey(directiveName)) {
        test:assertEquals(schemas[0].directives[directiveName], supergraph.schema.directives[directiveName]);
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