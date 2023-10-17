import graphql_schema_registry.parser;

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
|};