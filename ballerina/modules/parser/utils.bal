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
public const string _SERVICE_TYPE = "_Service";

public string[] BUILT_IN_TYPES = [
    _SERVICE_TYPE,
    BOOLEAN,
    STRING,
    FLOAT,
    INT,
    ID
];

public __DirectiveLocation[] EXECUTABLE_DIRECTIVE_LOCATIONS = [
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT
];
public string[] BUILT_IN_DIRECTIVES = [
    INCLUDE_DIR,
    DEPRECATED_DIR,
    SKIP_DIR,
    SPECIFIED_BY_DIR
];

public isolated function wrapType(__Type 'type, WRAPPING_TYPE kind) returns __Type {
    return {
        kind: kind,
        ofType: 'type
    };
}

public function isBuiltInDirective(string directiveName) returns boolean {
    return BUILT_IN_DIRECTIVES.indexOf(directiveName) !is ();
}

public function isExecutableDirective(__Directive directive) returns boolean {
    foreach __DirectiveLocation location in directive.locations {
        if EXECUTABLE_DIRECTIVE_LOCATIONS.indexOf(location) !is () {
            return true;
        }
    }
    return false;
}

public function isBuiltInType(string typeName) returns boolean {
    return BUILT_IN_TYPES.indexOf(typeName) !is ();
}