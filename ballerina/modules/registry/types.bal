const string PERSIST_EXTENSION = ".json";

type Version record {|
    int breaking;
    int dangerous;
    int safe;
|};

public type SchemaSnapshot record {|
    string supergraph;
    map<SubgraphSchema> subgraphs;
|};

public type SubgraphSchema record {|
    string name;
    string url;
    string sdl;
|};