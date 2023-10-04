import ballerina/jballerina.java;

public class Parser {

    private handle jObj;

    public function init(string schema) {
        self.jObj = newParser(schema);
    }

    public function parse() returns __Schema {
        return <__Schema>parse(self.jObj);
    }

}

function newParser(string schema) returns handle = @java:Constructor {
    'class: "io.xlibb.schemaregistry.Parser"
} external;

function parse(handle jObj) returns any = @java:Method {
    'class: "io.xlibb.schemaregistry.Parser"
} external;