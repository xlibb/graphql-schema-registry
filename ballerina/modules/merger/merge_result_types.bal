import graphql_schema_registry.parser;

type MergeResult record {|
    Hint[] hints;
|};

type InputValueMapMergeResult record {|
    *MergeResult;
    map<parser:__InputValue> result;
|};

type FieldMapMergeResult record {|
    *MergeResult;
    map<parser:__Field> result;
|};

type EnumValuesMergeResult record {|
    *MergeResult;
    parser:__EnumValue[] result;
|};

type DescriptionMergeResult record {|
    *MergeResult;
    string? result;
|};

type DefaultValueMergeResult record {|
    *MergeResult;
    anydata? result;
|};

type PossibleTypesMergeResult record {|
    *MergeResult;
    parser:__Type[] result;
    TypeReferenceSourceGroup[] sources; 
|};

type TypeReferenceMergeResult record {|
    *MergeResult;
    parser:__Type result;
    TypeReferenceSourceGroup[] sources; 
|};

public type SupergraphMergeResult record {|
    *MergeResult;
    Supergraph result;
|};