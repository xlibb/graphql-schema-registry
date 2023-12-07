import ballerina/test;
import ballerina/graphql;

graphql:Client testClient = check new ("http://localhost:9090");

@test:Config {
    groups: ["service"],
    dataProvider: dataProviderSchemaRegistryService,
    before: clearRegistry
}
function testSchemaRegistry(string testName, string[] subTests) returns error? {
    foreach string subTestName in subTests {
        [string, json] testData = check getTestData(testName, subTestName);
        json actual = check testClient->execute(document = testData[0], targetType = json);
        test:assertEquals(actual, testData[1], msg = string `Test failed on ${testName}.${subTestName}`);
    }
}

function dataProviderSchemaRegistryService() returns map<[string, string[]]>|error {
    return { 
        "shareable":            [
                                    "shareable",   
                                    [
                                        "1_no_supergraph", "2_first_dry_run", "3_first_subgraph", "4_second_dry_run", 
                                        "5_second_dry_run_forced", "6_second_subgraph_operation_check_fail", "7_second_subgraph", 
                                        "8_third_dry_run_forced", "9_subgraph_by_name", "10_supergraph_diff", "11_third_subgraph",
                                        "12_second_subgraph_add_shareable", "13_third_subgraph_retry", "14_no_subgraph_change"
                                    ]
                                ],
        "apollo_federation_airlock_2":    [
                                    "apollo_federation_airlock_2",
                                    [
                                        "1_monolith_schema",
                                        "2_accounts_subgraph_fail",
                                        "3_update_monolith_subgraph",
                                        "4_accounts_subgraph_retry",
                                        "5_update_monolith_subgraph",
                                        "6_update_accounts_subgraph"
                                    ]
                                ]
     };
}