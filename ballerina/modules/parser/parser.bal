import ballerina/jballerina.java;

public isolated class Parser {

    private final handle jObj;

    public isolated function init(string schema, ParsingMode mode) {
        self.jObj = newParser(schema, mode);
    }

    public isolated function parse() returns __Schema|error {
        return <__Schema>parse(self.jObj);
    }

}

public enum ParsingMode {
    SCHEMA,
    SUBGRAPH_SCHEMA,
    SUPERGRAPH_SCHEMA
}

isolated function newParser(string schema, string modeStr) returns handle = @java:Constructor {
    'class: "io.xlibb.schemaregistry.Parser"
} external;

isolated function parse(handle jObj) returns any = @java:Method {
    'class: "io.xlibb.schemaregistry.Parser"
} external;