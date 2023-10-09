import ballerina/jballerina.java;

public class Parser {

    private handle jObj;

    public function init(string schema, boolean isSubgraph) {
        self.jObj = newParser(schema, isSubgraph);
    }

    public function parse() returns __Schema {
        return <__Schema>parse(self.jObj);
    }

}

function newParser(string schema, boolean isSubgraph) returns handle = @java:Constructor {
    'class: "io.xlibb.schemaregistry.Parser"
} external;

function parse(handle jObj) returns any = @java:Method {
    'class: "io.xlibb.schemaregistry.Parser"
} external;