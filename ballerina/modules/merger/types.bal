import graphql_schema_registry.parser;

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
    boolean isSubgraph = false;
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

enum TypeReferenceType {
    INPUT,
    OUTPUT
}

public type EnumTypeUsage record {|
    boolean isUsedInOutputs;
    boolean isUsedInInputs;
|};

public type EntityStatus record {|
    boolean isEntity;
    boolean isResolvable;
    string? fields;
|};

type DescriptionSource [Subgraph, string?];
type PossibleTypesSource [Subgraph, parser:__Type[]];
type FieldMapSource [Subgraph, map<parser:__Field>];
type InputFieldMapSource [Subgraph, map<parser:__InputValue>];
type EnumValueSetSource [Subgraph, parser:__EnumValue[]];
type TypeReferenceSource [Subgraph, parser:__Type];
type DefaultValueSource [Subgraph, anydata?];
type DeprecationSource [Subgraph, [boolean, string?]];

type EnumValueSource [Subgraph, parser:__EnumValue];
type FieldSource [Subgraph, parser:__Field];
type InputSource [Subgraph, parser:__InputValue];

type TypeKindSources record {|
    parser:__TypeKind data;
    Subgraph[] subgraphs;
|};

type DescriptionSources record {|
    string? data;
    Subgraph[] subgraphs;
|};

type DefaultValueSources record {|
    anydata data;
    Subgraph[] subgraphs;
|};

type TypeReferenceSources record {|
    parser:__Type data;
    Subgraph[] subgraphs;
|};

type ConsistentInconsistenceSubgraphs record {|
    Subgraph[] consistent;
    Subgraph[] inconsistent;
|};

type HintDetail record {|
    anydata value;
    Subgraph[] consistentSubgraphs;
    Subgraph[] inconsistentSubgraphs;
|};

type Hint record {|
    string code;
    string[] location;
    HintDetail[] details;
|};

type MergedResult record {|
    anydata result;
    Hint[] hints;
|};

type PossibleTypesMergeResult record {|
    *MergedResult;
    TypeReferenceSources[] sources; 
|};

type TypeReferenceMergeResult record {|
    *MergedResult;
    TypeReferenceSources[] sources; 
|};