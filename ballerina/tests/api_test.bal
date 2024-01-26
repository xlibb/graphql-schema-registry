import ballerina/test;
import ballerina/graphql;
import graphql_schema_registry.datasource;
import ballerina/lang.runtime;

const port = 9090;
graphql:Listener graphqlListener = check new (port);

@test:Config {
    groups: ["service"],
    dataProvider: dataProviderSchemaRegistryService,
    before: clearRegistry
}
function testSchemaRegistry(string testName, string[] subTests) returns error? {
    graphql:Service registryService = getSchemaRegistryService(check new MongodbDatasource());
    check graphqlListener.attach(registryService);
    check graphqlListener.'start();
    runtime:registerListener(graphqlListener);
    graphql:Client testClient = check new (string `http://localhost:${port}`);
    foreach string subTestName in subTests {
        [string, json] testData = check getTestData(testName, subTestName);
        json actual = check testClient->execute(document = testData[0], targetType = json);
        test:assertEquals(actual, testData[1], msg = string `Test failed on ${testName}.${subTestName}`);
    }
    check graphqlListener.gracefulStop();
    check graphqlListener.detach(registryService);
    runtime:deregisterListener(graphqlListener);
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

@test:Config {
    groups: ["service"],
    dataProvider: dataProviderSchemaRegistryServiceDatasource,
    before: clearRegistry
}
function testSchemaRegistryDatasource(datasource:Datasource datasource) returns error? {
    string testName = "simple_example";
    string[] subTests = [
        "1_supergraph",
        "2_product_subgraph",
        "3_supergraph",
        "4_users_subgraph",
        "5_supergraph",
        "6_users_update",
        "7_supergraph",
        "8_versions",
        "9_diff",
        "10_reviews_error",
        "11_reviews_publish",
        "12_users_breaking_update",
        "13_users_forced_breaking_update"
    ];
    graphql:Service registryService = getSchemaRegistryService(datasource);
    check graphqlListener.attach(registryService);
    check graphqlListener.'start();
    runtime:registerListener(graphqlListener);
    graphql:Client testClient = check new (string `http://localhost:${port}`);
    foreach string subTestName in subTests {
        [string, json] testData = check getTestData(testName, subTestName);
        json actual = check testClient->execute(document = testData[0], targetType = json);
        test:assertEquals(actual, testData[1], msg = string `Test failed on ${testName}.${subTestName}`);
    }
    check graphqlListener.gracefulStop();
    check graphqlListener.detach(registryService);
    runtime:deregisterListener(graphqlListener);
}

function dataProviderSchemaRegistryServiceDatasource() returns datasource:Datasource[][]|error {
    return [
        [check new MongodbDatasource()],
        [check new FileDatasource("datasource")],
        [new InMemoryDatasource()]
    ];
}
