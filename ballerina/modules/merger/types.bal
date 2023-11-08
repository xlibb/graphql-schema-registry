import graphql_schema_registry.parser;

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
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

type SourceGroup record {|
    anydata data;
    Subgraph[] subgraphs;
|};