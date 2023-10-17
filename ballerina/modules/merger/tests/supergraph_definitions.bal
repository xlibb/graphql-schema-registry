import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "federation", "types", "nonconflicting"],
    dataProvider: dataProviderSupergraphTypes
}
function testSupergraphTypes(string typeName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("supergraph_definitions");
    parser:__Schema supergraph = merge(schemas[1]);

    if (schemas[0].types.hasKey(typeName) && supergraph.types.hasKey(typeName)) {
        test:assertEquals(schemas[0].types[typeName], supergraph.types[typeName]);
    } else {
        test:assertFail(string `Could not find '${typeName}'`);
    }
}

function dataProviderSupergraphTypes() returns [string][] {
    return [
        ["join__FieldSet"],
        ["link__Import"],
        ["link__Purpose"],
        ["join__Graph"]
    ];
}

@test:Config {
    groups: ["merger", "federation", "directives", "nonconflicting"],
    dataProvider: dataProviderSupergraphDirectives
}
function testSupergraphDirectives(string directiveName) returns error? {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("supergraph_definitions");
    parser:__Schema supergraph = merge(schemas[1]);

    if (schemas[0].directives.hasKey(directiveName) && supergraph.directives.hasKey(directiveName)) {
        test:assertEquals(schemas[0].directives[directiveName], supergraph.directives[directiveName]);
    } else {
        test:assertFail(string `Could not find '${directiveName}'`);
    }
}

function dataProviderSupergraphDirectives() returns [string][] {
    return [
        ["link"],
        ["join__graph"],
        ["join__unionMember"],
        ["join__enumValue"],
        ["join__field"],
        ["join__graph"],
        ["join__implements"],
        ["join__type"],
        ["join__unionMember"]
    ];
}