import ballerina/file;
import ballerina/io;
import ballerina/test;
import ballerinax/mongodb;

const REGISTRY_DATASOURCE = "datasource";

function getTestData(string testName, string subTestName) returns [string, json]|error {
    string basePath = check file:joinPath("tests", "resources", testName);
    string queriesPath = check file:joinPath(basePath, "queries", subTestName + ".graphql");
    string resultPath = check file:joinPath(basePath, "expected", subTestName + ".json");
    json result = check io:fileReadJson(resultPath);
    string query = check io:fileReadString(queriesPath);

    return [query, result];
}

@test:AfterSuite { }
function removeRegistry() returns file:Error? {
    check removeFileBasedRegistry();
}

function removeFileBasedRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath(REGISTRY_DATASOURCE);
    if check file:test(datasourcePath, file:IS_DIR) {
        check file:remove(datasourcePath, file:RECURSIVE);
    }
}

function clearRegistry() returns error? {
    check clearFileBasedRegistry();
    check clearMongoBasedRegistry();
}

function clearFileBasedRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath(REGISTRY_DATASOURCE);
    if check file:test(datasourcePath, file:IS_DIR) {
        check removeAndCreateDir(check file:joinPath(datasourcePath, "subgraphs"));
        check removeAndCreateDir(check file:joinPath(datasourcePath, "supergraph"));
    }
}

function clearMongoBasedRegistry() returns error? {
    mongodb:Client mongoClient = check new(mongoConfig);
    _ = check mongoClient->delete("supergraphs", filter = {}, isMultiple = true);
    _ = check mongoClient->delete("subgraphs", filter = {}, isMultiple = true);
    _ = check mongoClient->delete("supergraphSubgraphs", filter = {}, isMultiple = true);
}

function removeAndCreateDir(string path) returns file:Error? {
    if check file:test(path, file:IS_DIR) {
        check file:remove(path, file:RECURSIVE);
        check file:createDir(path, file:RECURSIVE);
    }
}