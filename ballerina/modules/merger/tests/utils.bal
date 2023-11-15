import ballerina/io;
import ballerina/file;
import graphql_schema_registry.parser;

type TestSchemas record {|
    parser:__Schema parsed;
    parser:__Schema merged;
|};

function getSubgraphsFromFileName(string folderName, string subgraph_prefix) returns Subgraph[]|error {
    Subgraph[] subgraphs = [];

    string path = check file:joinPath("modules", "merger", "tests", "resources", "subgraph_sdls", folderName);
    file:MetaData[] & readonly readDir = check file:readDir(path);
    
    int subgraph_no = 1;
    foreach file:MetaData data in readDir {
        if !data.dir && data.absPath.endsWith(".graphql") {
            string sdl = check io:fileReadString(data.absPath);
            parser:Parser parser = new(sdl, parser:SUBGRAPH_SCHEMA);
            parser:__Schema parsedSchema = check parser.parse();

            subgraphs.push(
                {
                    name: string `${subgraph_prefix}${subgraph_no}`,
                    url: string `http://${subgraph_prefix}${subgraph_no}`,
                    schema: parsedSchema
                }
            );

            subgraph_no += 1;
        }
    }
    return subgraphs;
}

function getSupergraphSdlFromFileName(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "merger", "tests", "resources", "expected_supergraphs", gqlFileName);
    return check io:fileReadString(path);
}

function getSupergraphFromFileName(string fileName) returns parser:__Schema|error {
    string sdl = check getSupergraphSdlFromFileName(fileName);
    parser:Parser parser = new(sdl, parser:SCHEMA);
    return check parser.parse();
}

function getSchemas(string fileName, string subgraph_prefix = "subg") returns [parser:__Schema, Subgraph[]]|error {
    Subgraph[] subgraphs = check getSubgraphsFromFileName(fileName, subgraph_prefix);
    parser:__Schema supergraph = check getSupergraphFromFileName(fileName);
    return [supergraph, subgraphs];
}

function getMergedAndParsedSchemas(string fileName) returns TestSchemas|error {
    [parser:__Schema, Subgraph[]] schemas = check getSchemas(fileName);
    parser:__Schema merged = (check (check new Merger(schemas[1])).merge()).schema;

    return {
        parsed: schemas[0],
        merged: merged
    };
}