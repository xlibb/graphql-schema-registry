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

public type EnumTypeUsage record {|
    boolean isUsedInOutputs;
    boolean isUsedInInputs;
|};

public type EntityStatus record {|
    boolean isEntity;
    boolean isResolvable;
    string[] keyFields;
|};

type DescriptionSource [string, string?];
type PossibleTypesSource [string, parser:__Type[]];
type FieldMapSource [string, map<parser:__Field>, boolean, string[]]; # subgraphName, subgraphFieldMap, isTypeShareable, entityFields
type InputFieldMapSource [string, map<parser:__InputValue>];
type EnumValueSetSource [string, parser:__EnumValue[]];
type TypeReferenceSource [string, parser:__Type];
type DefaultValueSource [string, anydata?];
type DeprecationSource [string, [boolean, string?]];

type EnumValueSource [string, parser:__EnumValue];
type FieldSource [string, parser:__Field, boolean];
type InputSource [string, parser:__InputValue];

type TypeKindSources record {|
    parser:__TypeKind data;
    string[] subgraphs;
|};

type DescriptionSources record {|
    string? data;
    string[] subgraphs;
|};

type DefaultValueSources record {|
    anydata data;
    string[] subgraphs;
|};

type TypeReferenceSources record {|
    parser:__Type data;
    string[] subgraphs;
|};

type ConsistentInconsistenceSubgraphs record {|
    string[] consistent;
    string[] inconsistent;
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

public type SupergraphMergeResult record {|
    Supergraph result;
    Hint[] hints;
|};