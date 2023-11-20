import ballerina/test;
import ballerina/io;

@test:Config {
    groups: ["registry"]
}
function testRegister() returns error? {
    Registry registry = check new();
    SubgraphSchema schema = {
        name: "subg2",
        url: "http://subg2",
        sdl: string `
        type Query {
            name: String
            age: Int
            value: Boolean
        }`
    };
    SupergraphSchema supergraphSchema = check registry.publishSubgraph(schema);

    schema = {
        name: "subg1",
        url: "http://subg1",
        sdl: string `
        type Query {
            name: String
            age: Int
        }`
    };
    supergraphSchema = check registry.publishSubgraph(schema);
    io:println(supergraphSchema.schema);
}