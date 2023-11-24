public type Supergraph record {|
    string schema;
    string apiSchema;
    string version;
    Subgraph[] subgraphs;
|};

public type Subgraph record {|
    string name;
    string url;
    string schema;
|};

public type ComposedSupergraphSchemas record {|
    string schema;
    string apiSchema;
|};

public enum VersionIncrementOrder {
    BREAKING,
    DANGEROUS,
    SAFE
}