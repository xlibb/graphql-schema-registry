public type Version record {|
    int breaking;
    int dangerous;
    int safe;
|};

public type SupergraphSchema record {|
    string schema;
    map<SubgraphSchema> subgraphs;
    Version version;
|};

public type InputSubgraph record {|
    string name;
    string url;
    string sdl;
|};

public type SubgraphSchema record {|
    *InputSubgraph;
    string id;
|};

public enum VersionIncrementOrder {
    BREAKING,
    DANGEROUS,
    SAFE
}