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