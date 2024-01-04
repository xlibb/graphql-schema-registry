import graphql_schema_registry.parser;

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
    boolean isFederation2Subgraph = false;
|};

public type Supergraph record {|
    parser:__Schema schema;
    Subgraph[] subgraphs;
|};

public type HintDetail record {|
    anydata value;
    string[] consistentSubgraphs;
    string[] inconsistentSubgraphs;
|};

public type Hint record {|
    string code;
    string[] location;
    HintDetail[] details;
|};

public type EnumTypeUsage record {|
    boolean isUsedInOutputs;
    boolean isUsedInInputs;
|};

public type EntityStatus record {|
    boolean isEntity;
    boolean isResolvable;
    string[] keyFields;
|};

type ConsistentInconsistenceSubgraphs record {|
    string[] consistent;
    string[] inconsistent;
|};