public type Supergraph record {|
    readonly string version;
    string schema;
    string apiSchema;
|};

public type Subgraph record {|
    readonly int id;
    readonly string name;
    string url;
    string schema;
|};

public type SupergraphSubgraph record {|
    readonly int id;
    string supergraphVersion;
    int subgraphId;
    string subgraphName;
|};

public type SupergraphInsert Supergraph;

public type SubgraphInsert record {|
    readonly string name;
    string url;
    string schema;
|};

public type SupergraphUpdate record {|
    string schema?;
    string apiSchema?;
|};

public type SubgraphUpdate record {|
    string url?;
    string schema?;
|};

public type SupergraphSubgraphInsert record {|
    string supergraphVersion;
    int subgraphId;
    string subgraphName;
|};

public type SupergraphSubgraphUpdate SupergraphSubgraphInsert;