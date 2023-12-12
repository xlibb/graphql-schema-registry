import ballerina/test;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "api_schema"]
}
function testApiSchema() returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("full_schema");
    parser:__Schema apiSchema = getApiSchema(schemas.merged);
    string exportedApiSchemaSdl = check exporter:export(apiSchema);
    test:assertEquals(exportedApiSchemaSdl, check getSupergraphSdlFromFileName("full_schema_api"));
}