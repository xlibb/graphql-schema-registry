import graphql_schema_registry.parser;

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
|};

public type Supergraph record {|
    parser:__Schema schema;
    Subgraph[] subgraphs;
|};

public type Mismatch record {|
    anydata data;
    Subgraph[] subgraphs;
|};

public type MergeResult record {|
    anydata? result;
    Mismatch[] hints;
|};