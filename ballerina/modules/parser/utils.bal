public type WRAPPING_TYPE NON_NULL | LIST;

public const string INCLUDE_DIR = "include";
public const string DEPRECATED_DIR = "deprecated";
public const string SKIP_DIR = "skip";
public const string SPECIFIED_BY_DIR = "specifiedBy";

public const string BOOLEAN = "Boolean";
public const string STRING = "String";
public const string FLOAT = "Float";
public const string INT = "Int";
public const string ID = "ID";
public const string QUERY_TYPE = "Query";
public const string MUTATION_TYPE = "Mutation";
public const string SUBSCRIPTION_TYPE = "Subscription";
public const string _SERVICE_TYPE = "_Service";

public type BUILT_IN_TYPES _SERVICE_TYPE | BOOLEAN | STRING | FLOAT | INT | ID;

public type EXECUTABLE_DIRECTIVE_LOCATIONS QUERY | MUTATION | SUBSCRIPTION | FIELD | FRAGMENT_DEFINITION | FRAGMENT_SPREAD | INLINE_FRAGMENT;

public type BUILT_IN_DIRECTIVES INCLUDE_DIR | DEPRECATED_DIR | SKIP_DIR | SPECIFIED_BY_DIR;

public isolated function wrapType(__Type 'type, WRAPPING_TYPE kind) returns __Type {
    return {
        kind: kind,
        ofType: 'type
    };
}

public isolated function isBuiltInDirective(string directiveName) returns boolean {
    return directiveName is BUILT_IN_DIRECTIVES;
}

public isolated function isExecutableDirective(__Directive directive) returns boolean {
    foreach __DirectiveLocation location in directive.locations {
        return location is EXECUTABLE_DIRECTIVE_LOCATIONS;
    }
    return false;
}

public isolated function isBuiltInType(string typeName) returns boolean {
    return typeName is BUILT_IN_TYPES;
}

public isolated function createSchema() returns __Schema {
    [map<__Type>, map<__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get(QUERY_TYPE)
    };
}

public isolated function createObjectType(string name, map<__Field> fields = {}, __Type[] interfaces = [], __AppliedDirective[] applied_directives = []) returns __Type {
    return {
        kind: OBJECT,
        name: name,
        fields: fields,
        interfaces: interfaces,
        appliedDirectives: applied_directives
    };
}

public isolated function createDirective(string name, string? description, __DirectiveLocation[] locations, map<__InputValue> args, boolean isRepeatable) returns __Directive {
    return {
        name,
        description,
        locations,
        args,
        isRepeatable
    };
}

public isolated function getBuiltInDefinitions() returns [map<__Type>, map<__Directive>] {
    __Type query_type = createObjectType(QUERY_TYPE);
    map<__Type> types = {};

    types[BOOLEAN] = {
                                kind: SCALAR,
                                name: BOOLEAN,
                                description: "Built-in Boolean"
                            };
    types[STRING] =  {
                                kind: SCALAR,
                                name: STRING,
                                description: "Built-in String"
                            };
    types[FLOAT] =   {
                                kind: SCALAR,
                                name: FLOAT,
                                description: "Built-in Float"
                            };
    types[INT] =     {
                                kind: SCALAR,
                                name: INT,
                                description: "Built-in Int"
                            };
    types[ID] =      {
                                kind: SCALAR,
                                name: ID,
                                description: "Built-in ID"
                            };
    types[QUERY_TYPE] = query_type;

    map<__Directive> directives = getBuiltInDirectives(types);

    return [ types, directives ];
}

isolated function getBuiltInDirectives(map<__Type> types) returns map<__Directive> {
    __Directive include = createDirective(
        INCLUDE_DIR,
        "Directs the executor to include this field or fragment only when the `if` argument is true",
        [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Included when true.",
                'type: wrapType(types.get(BOOLEAN), NON_NULL)
            }
        },
        false
    );
    __Directive deprecated = createDirective(
        DEPRECATED_DIR,
        "Marks the field, argument, input field or enum value as deprecated",
        [ FIELD_DEFINITION, ARGUMENT_DEFINITION, ENUM_VALUE, INPUT_FIELD_DEFINITION ],
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
    __Directive specifiedBy = createDirective(
        SPECIFIED_BY_DIR,
        "Exposes a URL that specifies the behaviour of this scalar.",
        [ SCALAR ],
        {
            "url": {
                name: "url",
                description: "The URL that specifies the behaviour of this scalar.",
                'type: wrapType(types.get(STRING), NON_NULL)
            }
        },
        false
    );
    __Directive skip = createDirective(
        SKIP_DIR,
        "Directs the executor to skip this field or fragment when the `if` argument is true.",
        [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Skipped when true.",
                'type: wrapType(types.get(BOOLEAN), NON_NULL)
            }
        },
        false
    );

    map<__Directive> directives = {};
    directives[INCLUDE_DIR] = include;
    directives[DEPRECATED_DIR] = deprecated;
    directives[SKIP_DIR] = skip;
    directives[SPECIFIED_BY_DIR] = specifiedBy;

    return directives;
}