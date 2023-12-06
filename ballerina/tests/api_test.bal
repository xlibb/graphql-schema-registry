import ballerina/test;
import ballerina/graphql;
import ballerina/file;

@test:AfterGroups { value:["service"] }
function clearRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath("datasource");
    if check file:test(datasourcePath, file:IS_DIR) {
        check file:remove(datasourcePath, file:RECURSIVE);
    }
}

graphql:Client testClient = check new ("http://localhost:9090");

@test:Config {
    groups: ["service"],
    dataProvider: dataProviderSchemaRegistryService
}
function testSchemaRegistry(string testName) returns error? {
    [string, json] testData = check getTestData(testName);
    json actual = check testClient->execute(document = testData[0], targetType = json);
    test:assertEquals(actual, testData[1]);
}

function dataProviderSchemaRegistryService() returns [string][]|error {

    return [
        ["1_no_supergraph"],
        ["2_first_dry_run"],
        ["3_first_subgraph"],
        ["4_second_dry_run"],
        ["5_second_dry_run_forced"],
        ["6_second_subgraph_operation_check_fail"],
        ["7_second_subgraph"],
        ["8_third_dry_run_forced"],
        ["9_subgraph_by_name"],
        ["10_supergraph_diff"],
        ["11_third_subgraph"],
        ["12_second_subgraph_add_shareable"],
        ["13_third_subgraph_retry"],
        ["14_no_subgraph_change"]
    ];
}