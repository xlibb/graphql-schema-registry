import ballerina/test;
import graphql_schema_registry.parser;
import ballerina/io;

@test:Config {
    groups: ["exporter"]
}
function testConflictCompatibleInputTypes() returns error? {
    string expectedSdl = check getSchemaSdl("sample");
    string actualSdl = check (new Exporter(check new parser:Parser(expectedSdl, parser:SCHEMA).parse())).export();
    io:print(actualSdl);
}