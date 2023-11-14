import ballerina/file;
import ballerina/io;
function getSchemaSdl(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "exporter", "tests", "resources", gqlFileName);
    string sdl = check io:fileReadString(path);
    return sdl;
}

function writeSchemaSdl(string fileName, string content) returns error? {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "exporter", "tests", "resources", gqlFileName);
    check io:fileWriteString(path, content);
}