import ballerina/file;
import ballerina/io;
import ballerina/test;

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
    string datasourcePath = check file:joinPath(REGISTRY_DATASOURCE);
    check file:remove(datasourcePath, file:RECURSIVE);
}

function clearRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath(REGISTRY_DATASOURCE);
    check removeAndCreateDir(check file:joinPath(datasourcePath, "subgraphs"));
    check removeAndCreateDir(check file:joinPath(datasourcePath, "supergraph"));
}

function removeAndCreateDir(string path) returns file:Error? {
    if check file:test(path, file:IS_DIR) {
        check file:remove(path, file:RECURSIVE);
        check file:createDir(path, file:RECURSIVE);
    }
}