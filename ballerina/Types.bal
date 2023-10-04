public type __Schema record {|
    string? description = ();
    map<__Type> types;
    __Type queryType;
    __Type? mutationType = ();
    __Type? subscriptionType = ();
    map<__Directive> directives;
|};

public type __Type record {|
    __TypeKind kind;
    string? name = ();
    string? description = ();
    map<__Field>? fields = ();
    __Type[]? interfaces = ();
    __Type[]? possibleTypes = ();
    __EnumValue[]? enumValues = ();
    map<__InputValue>? inputFields = ();
    __Type? ofType = ();
|};

public type __Directive record {|
    string name;
    string? description = ();
    __DirectiveLocation[] locations = [];
    __InputValue[] args = [];
    boolean isRepeatable;
|};

public enum __DirectiveLocation {
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT,
    VARIABLE_DEFINITION,
    SCHEMA,
    SCALAR,
    OBJECT,
    FIELD_DEFINITION,
    ARGUMENT_DEFINITION,
    INTERFACE,
    UNION,
    ENUM,
    ENUM_VALUE,
    INPUT_OBJECT,
    INPUT_FIELD_DEFINITION
}

public enum __TypeKind {
    SCALAR,
    OBJECT,
    INTERFACE,
    UNION,
    ENUM,
    INPUT_OBJECT,
    LIST,
    NON_NULL
}

public type __Field record {|
    string name;
    string? description = ();
    map<__InputValue> args;
    __Type 'type;
    boolean isDeprecated = false;
    string? deprecationReason = ();
|};

public type __InputValue record {|
    string name;
    string? description = ();
    __Type 'type;
    any? defaultValue = ();
|};

public type __EnumValue record {|
    string name;
    string? description = ();
    boolean isDeprecated = false;
    string? deprecationReason = ();
|};