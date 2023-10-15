import ballerina/io;
import ballerina/file;
isolated function getGraphqlSdlFromFile(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "parser", "tests", "resources", "sdl", gqlFileName);
    return io:fileReadString(path);
}