import graphql_schema_registry.parser;

# [subgraphName, graphqlTypeDefinition]
type DescriptionSource [string, string?];
type PossibleTypesSource [string, parser:__Type[]];
type FieldMapSource [string, map<parser:__Field>, boolean, EntityStatus]; # [.., isTypeShareable, entityFields]
type InputFieldMapSource [string, map<parser:__InputValue>];
type EnumValueSetSource [string, parser:__EnumValue[]];
type TypeReferenceSource [string, parser:__Type];
type DefaultValueSource [string, anydata?];
type DeprecationSource [string, [boolean, string?]];
type EnumValueSource [string, parser:__EnumValue];
type FieldSource [string, parser:__Field, boolean];
type InputSource [string, parser:__InputValue];

type SourceGroup record {|
    string[] subgraphs;
|};
type TypeKindSourceGroup record {|
    *SourceGroup;
    parser:__TypeKind data;
|};
type DescriptionSourceGroup record {|
    *SourceGroup;
    string? data;
|};
type DefaultValueSourceGroup record {|
    *SourceGroup;
    anydata data;
|};
type TypeReferenceSourceGroup record {|
    *SourceGroup;
    parser:__Type data;
|};
type TypeKindSourceGroupMap map<TypeKindSourceGroup>;