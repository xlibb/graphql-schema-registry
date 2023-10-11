import ballerina/io;
public function main() returns error? {

    string schemaSdl = string `
        scalar Test @specifiedBy(url: "adf")

        type Query {
            m: String
        }
    `;

    Parser parser = new(schemaSdl, SUBGRAPH_SCHEMA);
    __Schema schema = check parser.parse();

    io:println(schema.directives.toBalString());

}