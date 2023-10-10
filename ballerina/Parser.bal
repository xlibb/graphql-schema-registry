import ballerina/jballerina.java;

public class Parser {

    private handle jObj;

    public function init(string schema, ParsingMode mode) {
        self.jObj = newParser(schema, mode);
    }

    public function parse() returns __Schema {
        return <__Schema>parse(self.jObj);
    }

}

public enum ParsingMode {
    SCHEMA,
    SUBGRAPH_SCHEMA,
    SUPERGRAPH_SCHEMA
}

function newParser(string schema, string modeStr) returns handle = @java:Constructor {
    'class: "io.xlibb.schemaregistry.Parser"
} external;

function parse(handle jObj) returns any = @java:Method {
    'class: "io.xlibb.schemaregistry.Parser"
} external;