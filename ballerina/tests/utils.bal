import ballerina/file;
import ballerina/io;
import ballerina/test;

function getTestData(string testName, string subTestName) returns [string, json]|error {
    string basePath = check file:joinPath("tests", "resources", testName);
    string queriesPath = check file:joinPath(basePath, "queries", subTestName + ".graphql");
    string resultPath = check file:joinPath(basePath, "expected", subTestName + ".json");
    json result = check io:fileReadJson(resultPath);
    string query = check io:fileReadString(queriesPath);

    return [query, result];
}

@test:AfterGroups { value:["service"] }
function clearRegistry() returns file:Error? {
    string datasourcePath = check file:joinPath("datasource");
    if check file:test(datasourcePath, file:IS_DIR) {
        check file:remove(datasourcePath, file:RECURSIVE);
    }
}