import graphql_schema_registry.parser;

const string BOOLEAN = "Boolean";
const string STRING = "String";
const string FLOAT = "Float";
const string INT = "Int";
const string ID = "ID";
const string QUERY = "Query";

const string INCLUDE_DIR = "include";
const string DEPRECATED_DIR = "deprecated";
const string SKIP_DIR = "skip";
const string SPECIFIED_BY_DIR = "specifiedBy";

string[] BUILT_IN_DIRECTIVES = [
    INCLUDE_DIR,
    DEPRECATED_DIR,
    SKIP_DIR,
    SPECIFIED_BY_DIR
];

string[] BUILT_IN_TYPES = [
    STRING,
    FLOAT,
    INT,
    ID
];

parser:__DirectiveLocation[] EXECUTABLE_DIRECTIVE_LOCATIONS = [
    parser:QUERY,
    parser:MUTATION,
    parser:SUBSCRIPTION,
    parser:FIELD,
    parser:FRAGMENT_DEFINITION,
    parser:FRAGMENT_SPREAD,
    parser:INLINE_FRAGMENT
];

function createSchema() returns parser:__Schema {
    [map<parser:__Type>, map<parser:__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get("Query")
    };
}

function createObjectType(string name, map<parser:__Field> fields = {}, parser:__Type[] interfaces = [], parser:__AppliedDirective[] applied_directives = []) returns parser:__Type {
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

// Get the __AppliedDirective for a given __Directive and it's arguments. Default arguments will be added automatically.
function getAppliedDirectiveFromDirective(parser:__Directive directive, map<anydata> arguments) returns parser:__AppliedDirective|InternalError {
    map<parser:__AppliedDirectiveInputValue> applied_args = directive.args.'map(m => { 
                                                                                        value: m.defaultValue, 
                                                                                        definition: m.'type 
                                                                                     }
                                                                                );

    foreach [string, anydata] [key, value] in arguments.entries() {
        if (applied_args.hasKey(key)) {
            applied_args[key].value = value;
        } else {
            return error InternalError(string `'${key}' is not a parameter in the directive (${applied_args.toJsonString()})`);
        }
    }

    return {
        args: applied_args,
        definition: directive
    };
}

function isExecutableDirective(parser:__Directive directive) returns boolean {
    foreach parser:__DirectiveLocation location in directive.locations {
        if EXECUTABLE_DIRECTIVE_LOCATIONS.indexOf(location) !is () {
            return true;
        }
    }
    return false;
}

function isBuiltInDirective(string directiveName) returns boolean {
    return BUILT_IN_DIRECTIVES.indexOf(directiveName) !is ();
}

function isBuiltInType(string typeName) returns boolean {
    return BUILT_IN_TYPES.indexOf(typeName) !is ();
}

function getDirectiveLocationsFromStrings(string[] locations) returns parser:__DirectiveLocation[]|InternalError {
    parser:__DirectiveLocation[] enumLocations = [];
    foreach string location in locations {
        enumLocations.push(check getDirectiveLocationFromString(location));
    }
    return enumLocations;
}

// Change parser to Parse DirectiveLocations as enums
function getDirectiveLocationFromString(string location) returns parser:__DirectiveLocation|InternalError {
    match location {
        "QUERY" => { return parser:QUERY; }
        "MUTATION" => { return parser:MUTATION; }
        "SUBSCRIPTION" => { return parser:SUBSCRIPTION; }
        "FIELD" => { return parser:FIELD; }
        "FRAGMENT_DEFINITION" => { return parser:FRAGMENT_DEFINITION; }
        "FRAGMENT_SPREAD" => { return parser:FRAGMENT_SPREAD; }
        "INLINE_FRAGMENT" => { return parser:INLINE_FRAGMENT; }
        "VARIABLE_DEFINITION" => { return parser:VARIABLE_DEFINITION; }
        "SCHEMA" => { return parser:SCHEMA; }
        "SCALAR" => { return parser:SCALAR; }
        "OBJECT" => { return parser:OBJECT; }
        "FIELD_DEFINITION" => { return parser:FIELD_DEFINITION; }
        "ARGUMENT_DEFINITION" => { return parser:ARGUMENT_DEFINITION; }
        "INTERFACE" => { return parser:INTERFACE; }
        "UNION" => { return parser:UNION; }
        "ENUM" => { return parser:ENUM; }
        "ENUM_VALUE" => { return parser:ENUM_VALUE; }
        "INPUT_OBJECT" => { return parser:INPUT_OBJECT; }
        "INPUT_FIELD_DEFINITION" => { return parser:INPUT_FIELD_DEFINITION; }
        _ => { return error InternalError(string `Provided value '${location}' is not a valid Directive Location`); }
    }
}

function typeReferenceToString(parser:__Type 'type) returns string|InternalError {
    match 'type.kind {
        parser:LIST => { 
            parser:__Type? ofType = 'type.ofType;
            if ofType is parser:__Type {
                return string `[${check typeReferenceToString(ofType)}]`; 
            } else {
                return error InternalError(string `Invalid wrapping type '${'type.toBalString()}'`);
            }
        }
        parser:NON_NULL => { 
            parser:__Type? ofType = 'type.ofType;
            if ofType is parser:__Type {
                return string `${check typeReferenceToString(ofType)}!`; 
            } else {
                return error InternalError(string `Invalid wrapping type '${'type.toBalString()}'`);
            }
        }
        _ => { return 'type.name ?: error InternalError(string `Invalid type name on '${'type.toBalString()}'`); }
    }
}