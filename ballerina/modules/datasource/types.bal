public type Version record {|
    int breaking;
    int dangerous;
    int safe;
|};

public type SupergraphSchema record {|
    string schema;
    map<SubgraphSchema> subgraphs;
    Version? version = ();
|};

public type SubgraphSchema record {|
    string name;
    string url;
    string sdl;
|};