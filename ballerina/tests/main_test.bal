// import ballerina/io;
import ballerina/test;

@test:Config {
    groups: ["g1"]
}
function intAddTest() {
    test:assertEquals(5, 5);
}