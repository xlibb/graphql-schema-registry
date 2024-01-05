import graphql_schema_registry.parser;

type SubgraphSource record {|
    string subgraph;
|};
type DescriptionSource record {|
    *SubgraphSource;
    string? definition;
|};
type PossibleTypesSource record {|
    *SubgraphSource;
    parser:__Type[] definition;
|};
type FieldMapSource record {|
    *SubgraphSource;
    map<parser:__Field> definition;
    boolean isDefiningTypeShareable;
    EntityStatus entityStatus;
|};
type InputFieldMapSource record {|
    *SubgraphSource;
    map<parser:__InputValue> definition;
|};
type EnumValueSetSource record {|
    *SubgraphSource;
    parser:__EnumValue[] definition;
|};
type TypeReferenceSource record {|
    *SubgraphSource;
    parser:__Type definition;
|};
type DefaultValueSource record {|
    *SubgraphSource;
    anydata? definition;
|};
type DeprecationSource record {|
    *SubgraphSource;
    [boolean, string?] definition;
|};
type EnumValueSource record {|
    *SubgraphSource;
    parser:__EnumValue definition;
|};
type FieldSource record {|
    *SubgraphSource;
    parser:__Field definition;
    boolean isAllowedToMerge;
|};
type InputValueSource record {|
    *SubgraphSource;
    parser:__InputValue definition;
|};

type SubgraphSourceGroup record {|
    string[] subgraphs;
|};
type TypeKindSourceGroup record {|
    *SubgraphSourceGroup;
    parser:__TypeKind data;
|};
type DescriptionSourceGroup record {|
    *SubgraphSourceGroup;
    string? data;
|};
type DefaultValueSourceGroup record {|
    *SubgraphSourceGroup;
    anydata data;
|};
type TypeReferenceSourceGroup record {|
    *SubgraphSourceGroup;
    parser:__Type data;
|};

type TypeKindSourceGroupMap map<TypeKindSourceGroup>;