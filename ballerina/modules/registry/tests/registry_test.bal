import ballerina/test;
import ballerina/io;

@test:Config {
    groups: ["persist"]
}
function testRegister() returns error? {
    Registry registry = check new();
    string|error composeResult = (check registry.publishSubgraph({
        name: "subg1", 
        url: "http://subg1",
        sdl: string `
        type Query {
            name: String
            age: Int
        }`})).supergraph;
    if composeResult is string {
        io:println(composeResult);
    } else {
        return composeResult;
    }

    composeResult = (check registry.publishSubgraph({
        name: "subg2",
        url: "http://subg2",
        sdl: string `
        type Query {
            name: String
            age: Int
            value: Boolean
        }`})).supergraph;
    if composeResult is string {
        io:println(composeResult);
    } else {
        return composeResult;
    }
}