import ballerina/io;
import ballerina/file;
isolated function getGraphqlSdlFromFile(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "parser", "tests", "resources", "sdl", gqlFileName);
    return io:fileReadString(path);
}

isolated function parseSdl(string sdl, ParsingMode mode = SCHEMA) returns __Schema|error {
    Parser parser = new(sdl, mode);
    __Schema|SchemaError[] parsedSchema = parser.parse();
    if parsedSchema is SchemaError[] {
        return getSchemaErrorsAsError(parsedSchema);
    }
    return parsedSchema;
}