import ballerina/test;

@test:Config {
    groups: ["merger", "compatible", "federation_definitions"],
    dataProvider: dataProviderFederationSupergraphTypes
}
function testSupergraphFederationTypes(TestSchemas schemas, string typeName) {
    if (schemas.parsed.types.hasKey(typeName) && schemas.merged.types.hasKey(typeName)) {
        test:assertEquals(schemas.merged.types[typeName], schemas.parsed.types[typeName]);
    } else {
        test:assertFail(string `Could not find '${typeName}'`);
    }
}

function dataProviderFederationSupergraphTypes() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("supergraph_definitions");

    return [
        [schemas, JOIN_FIELDSET_TYPE],
        [schemas, LINK_IMPORT_TYPE],
        [schemas, LINK_PURPOSE_TYPE],
        [schemas, JOIN_GRAPH_TYPE]
    ];
}

@test:Config {
    groups: ["merger", "compatible", "federation_definitions"],
    dataProvider: dataProviderSupergraphFederationDirectives
}
function testSupergraphFederationDirectives(TestSchemas schemas, string directiveName) returns error? {
    if (schemas.parsed.directives.hasKey(directiveName) && schemas.merged.directives.hasKey(directiveName)) {
        test:assertEquals(schemas.parsed.directives[directiveName], schemas.merged.directives[directiveName]);
    } else {
        test:assertFail(string `Could not find '${directiveName}'`);
    }
}

function dataProviderSupergraphFederationDirectives() returns [TestSchemas, string][]|error {
    TestSchemas schemas = check getMergedAndParsedSchemas("supergraph_definitions");

    return [
        [schemas, LINK_DIR],
        [schemas, JOIN_GRAPH_DIR],
        [schemas, JOIN_UNION_MEMBER_DIR],
        [schemas, JOIN_ENUMVALUE_DIR],
        [schemas, JOIN_FIELD_DIR],
        [schemas, JOIN_IMPLEMENTS_DIR],
        [schemas, JOIN_TYPE_DIR]
    ];
}