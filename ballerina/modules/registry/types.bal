import graphql_schema_registry.parser;
import graphql_schema_registry.differ;
import graphql_schema_registry.merger;

public type Supergraph record {|
    string schemaSdl;
    string apiSchemaSdl;
    string version;
    Subgraph[] subgraphs;
|};

public type CompositionResult record {|
    *Supergraph;
    string[] hints;
    differ:SchemaDiff[] diffs;
|};

public type ComposedSupergraphSchemas record {|
    parser:__Schema schema;
    parser:__Schema apiSchema;
    string schemaSdl;
    string apiSchemaSdl;
    merger:Hint[] hints;
|};

public type Subgraph record {|
    string name;
    string url;
    string schema;
|};

type DiffResult record {|
    string version;
    differ:SchemaDiff[] diffs;
|};