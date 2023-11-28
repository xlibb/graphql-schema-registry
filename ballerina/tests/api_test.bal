import ballerina/test;
import ballerina/graphql;
import ballerina/file;

function clearRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath("datasource");
    if check file:test(datasourcePath, file:IS_DIR) {
        check file:remove(datasourcePath, file:RECURSIVE);
    }
}

@test:Config {
    groups: ["service"],
    dataProvider: dataProviderSchemaRegistryService
}
function testSchemaRegistry(string testName) returns error? {
    [string, json] testData = check getTestData(testName);
    graphql:Client testClient = check new ("http://localhost:9090");
    json actual = check testClient->execute(document = testData[0], targetType = json);
    test:assertEquals(actual, testData[1]);
}


function dataProviderSchemaRegistryService() returns [string][]|error {

    return [
        ["1_no_supergraph"],
        ["2_first_dry_run"],
        ["3_first_subgraph"],
        ["4_second_dry_run"],
        ["5_second_subgraph"],
        ["6_third_dry_run"]
    ];
}