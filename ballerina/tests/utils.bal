import ballerina/file;
import ballerina/io;

function getTestData(string testname) returns [string, json]|error {
    string basePath = check file:joinPath("tests", "resources");
    string queriesPath = check file:joinPath(basePath, "queries", testname + ".graphql");
    string resultPath = check file:joinPath(basePath, "expected", testname + ".json");
    json result = check io:fileReadJson(resultPath);
    string query = check io:fileReadString(queriesPath);

    return [query, result];
}