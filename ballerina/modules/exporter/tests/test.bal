import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["exporter"],
    dataProvider: dataProviderExporter
}
function testConflictCompatibleInputTypes(string fileName) returns error? {
    string expectedSdl = check getSchemaSdl(fileName);
    string actualSdl = check (new Exporter(check new parser:Parser(expectedSdl, parser:SCHEMA).parse())).export();
    if expectedSdl != actualSdl {
        check writeSchemaSdl(fileName + "_new", actualSdl);
    }
    test:assertEquals(actualSdl, expectedSdl);
}

function dataProviderExporter() returns [string][] {
    return [
        ["multiple_subgraphs_realworld_example"],
        ["multiple_subgraphs_conflicting_objects"],
        ["multiple_subgraphs_conflicting_enum_types"],
        ["multiple_subgraphs_join__type_and_join__Graph"],
        ["multiple_subgraphs_key_directive"],
        ["multiple_subgraphs_conflicting_union_types"],
        ["multiple_subgraphs_conflicting_interface_implements"],
        ["multiple_subgraphs_conflicting_interfaces"],
        ["multiple_subgraphs_nonconflicting_interfaces"],
        ["multiple_subgraphs_conflicting_compatible_output_types"],
        ["interface_implements"]
        // ["multiple_subgraphs_conflicting_compatible_input_types"]
    ];
}