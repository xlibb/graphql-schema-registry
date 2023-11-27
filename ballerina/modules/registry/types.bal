public type Supergraph record {|
    string schema;
    string apiSchema;
    string version;
    Subgraph[] subgraphs;
    string[] hints;
|};

public type Subgraph record {|
    string name;
    string url;
    string schema;
|};

public type ComposedSupergraphSchemas record {|
    string schema;
    string apiSchema;
    string[] hints;
|};

public enum VersionIncrementOrder {
    BREAKING,
    DANGEROUS,
    SAFE
}