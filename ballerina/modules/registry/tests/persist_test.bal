import ballerina/test;
import ballerina/io;

@test:Config {
    groups: ["persist"]
}
function testPersistRegister() returns error? {
    Persist persist = check new("./datasource");

    SchemaSnapshot record1 = {
        subgraphs: { 
            "subgraph-1": { name: "subgraph-1", sdl: "subgraph-1-sdl", url: "http://subg1"}
        },
        supergraph: "supergraph-sdl"
    };
    check persist.register(record1);

    SchemaSnapshot record2 = {
        subgraphs: { 
            "subgraph-2": { name: "subgraph-2", sdl: "subgraph-2-sdl", url: "http://subg2"},
            "subgraph-1": { name: "subgraph-1", sdl: "subgraph-1-sdl", url: "http://subg1"}
        },
        supergraph: "supergraph-sdl-2"
    };
    check persist.register(record2);
}

@test:Config {
    groups: ["persist"]
}
function testPersistGet() returns error? {
    Persist persist = check new("./datasource");
    io:println(persist.getLatestSchemas());
}