import graphql_schema_registry.parser;

string & readonly BOOLEAN = "Boolean";
string & readonly STRING = "String";
string & readonly FLOAT = "Float";
string & readonly INT = "Int";
string & readonly ID = "ID";
string & readonly QUERY = "Query";

string & readonly INCLUDE_DIR = "include";
string & readonly DEPRECATED_DIR = "deprecated";
string & readonly SKIP_DIR = "skip";
string & readonly SPECIFIED_BY_DIR = "specifiedBy";

function createObjectType(string name, map<parser:__Field> fields = {}, parser:__Type[] interfaces = [], map<parser:__AppliedDirective> applied_directives = {}) returns parser:__Type {
    return {
        kind: parser:OBJECT,
        name: name,
        fields: fields,
        interfaces: interfaces,
        appliedDirectives: applied_directives
    };
}

function createDirective(string name, string? description, parser:__DirectiveLocation[] locations, map<parser:__InputValue> args, boolean isRepeatable) returns parser:__Directive {
    return {
        name,
        description,
        locations,
        args,
        isRepeatable
    };
}
function getBuiltInDefinitions() returns [map<parser:__Type>, map<parser:__Directive>] {
    parser:__Type query_type = createObjectType(QUERY);
    map<parser:__Type> types = {};

    types[BOOLEAN] = parser:gql_Boolean.clone();
    types[STRING] = parser:gql_String.clone();
    types[FLOAT] = parser:gql_Float.clone();
    types[INT] = parser:gql_Int.clone();
    types[ID] = parser:gql_ID.clone();
    types[QUERY] = query_type;

    map<parser:__Directive> directives = getBuiltInDirectives(types);

    return [ types, directives ];
}

function getBuiltInDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive include = createDirective(
        INCLUDE_DIR,
        "Directs the executor to include this field or fragment only when the `if` argument is true",
        [ parser:FIELD, parser:FRAGMENT_SPREAD, parser:INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Included when true.",
                'type: parser:wrapType(types.get(BOOLEAN), parser:NON_NULL)
            }
        },
        false
    );
    parser:__Directive deprecated = createDirective(
        DEPRECATED_DIR,
        "Marks the field, argument, input field or enum value as deprecated",
        [ parser:FIELD_DEFINITION, parser:ARGUMENT_DEFINITION, parser:ENUM_VALUE, parser:INPUT_FIELD_DEFINITION ],
        {
            "reason": {
                name: "reason",
                description: "The reason for the deprecation",
                'type: types.get(STRING),
                defaultValue: "No longer supported"
            }
        },
        false
    );
    parser:__Directive specifiedBy = createDirective(
        SPECIFIED_BY_DIR,
        "Exposes a URL that specifies the behaviour of this scalar.",
        [ parser:SCALAR ],
        {
            "url": {
                name: "url",
                description: "The URL that specifies the behaviour of this scalar.",
                'type: parser:wrapType(types.get(STRING), parser:NON_NULL)
            }
        },
        false
    );
    parser:__Directive skip = createDirective(
        SKIP_DIR,
        "Directs the executor to skip this field or fragment when the `if` argument is true.",
        [ parser:FIELD, parser:FRAGMENT_SPREAD, parser:INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Skipped when true.",
                'type: parser:wrapType(types.get(BOOLEAN), parser:NON_NULL)
            }
        },
        false
    );

    map<parser:__Directive> directives = {};
    directives[INCLUDE_DIR] = include;
    directives[DEPRECATED_DIR] = deprecated;
    directives[SKIP_DIR] = skip;
    directives[SPECIFIED_BY_DIR] = specifiedBy;

    return directives;
}