import ballerina/test;
import graphql_schema_registry.exporter;
import ballerina/io;

@test:Config {
    groups: ["merger", "sdls"],
    dataProvider: dataProviderMergedSdls
}
function testMergedSdls(string fileName) returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas(fileName);

    string exportedSdl = check exporter:export(schemas.merged);
    string expectedSdl = check getSupergraphSdlFromFileName(fileName);
    if expectedSdl !== exportedSdl {
        check io:fileWriteString(string `./modules/merger/tests/resources/expected_supergraphs/${fileName}_1.graphql`, exportedSdl);
    }
    test:assertEquals(exportedSdl, check getSupergraphSdlFromFileName(fileName));
}

function dataProviderMergedSdls() returns [string][] {
    return [
        ["directive_definition_presence"],
        ["multiple_subgraphs_conflicting_compatible_enum_types"],
        ["multiple_subgraphs_conflicting_compatible_input_types"],
        ["multiple_subgraphs_conflicting_compatible_interfaces"],
        ["multiple_subgraphs_conflicting_compatible_objects"],
        ["multiple_subgraphs_conflicting_compatible_output_types"],
        ["multiple_subgraphs_conflicting_compatible_union_types"],
        ["multiple_subgraphs_conflicting_interface_implements"],
        ["multiple_subgraphs_join__Graph"],
        ["multiple_subgraphs_join__type"],
        ["multiple_subgraphs_key"],
        ["multiple_subgraphs_nonconflicting_types"],
        ["multiple_subgraphs_shareable"],
        ["multiple_subgraphs_types_description"],
        ["single_subgraph_join__type"],
        ["supergraph_definitions"],
        ["full_schema"]
    ];
}