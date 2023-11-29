import ballerina/file;
import ballerina/io;
import graphql_schema_registry.parser;

string basePath = check file:joinPath("modules", "differ", "tests", "resources");

function getExpectedDiffs(string fileName) returns SchemaDiff[]|error {
    string expectedDiffPath = check file:joinPath(basePath, "expected_diffs", fileName + ".json");
    json expectedDiffsJson = check io:fileReadJson(expectedDiffPath);
    SchemaDiff[] expectedDiffs = check expectedDiffsJson.cloneWithType();
    return expectedDiffs;
}

function getSchemas(string fileName) returns [parser:__Schema, parser:__Schema]|error {
    string schemasPath = check file:joinPath(basePath, "schemas", fileName);
    string newSchemaSdlPath = check file:joinPath(schemasPath, "new.graphql");
    string oldSchemaSdlPath = check file:joinPath(schemasPath, "old.graphql");

    string newSchemaSdl = check io:fileReadString(newSchemaSdlPath);
    string oldSchemaSdl = check io:fileReadString(oldSchemaSdlPath);

    parser:__Schema newSchema = check (new parser:Parser(newSchemaSdl, parser:SCHEMA)).parse();
    parser:__Schema oldSchema = check (new parser:Parser(oldSchemaSdl, parser:SCHEMA)).parse();

    return [newSchema, oldSchema];
}