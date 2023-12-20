public type Supergraph record {|
    readonly string version;
    string schema;
    string apiSchema;
|};

public type SubgraphId record {|
    readonly string version;
    readonly string name;
|};

public type Subgraph record {|
    *SubgraphId;
    string url;
    string schema;
|};

public type SubgraphInsert record {|
    readonly string name;
    string url;
    string schema;
|};

public type SupergraphInsert record {|
    *Supergraph;
    SubgraphId[] subgraphs;
|};

public type SupergraphUpdate record {|
    *Supergraph;
    SubgraphId[] subgraphs;
|};