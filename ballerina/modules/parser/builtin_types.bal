// Built-in Scalars
public __Type gql_Boolean = {
    kind: SCALAR,
    name: BOOLEAN,
    description: "Built-in Boolean"
};
public __Type gql_String = {
    kind: SCALAR,
    name: STRING,
    description: "Built-in String"
};
public __Type gql_Float = {
    kind: SCALAR,
    name: FLOAT,
    description: "Built-in Float"
};
public __Type gql_Int = {
    kind: SCALAR,
    name: INT,
    description: "Built-in Int"
};
public __Type gql_ID = {
    kind: SCALAR,
    name: ID,
    description: "Built-in ID"
};

// Built-in Directives
public __Directive include = {
    name: INCLUDE_DIR,
    locations: [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
    description: "Directs the executor to include this field or fragment only when the `if` argument is true",
    args: {
        "if": {
            name: "if",
            description: "Included when true.",
            'type: {
                kind: NON_NULL,
                ofType: gql_Boolean
            }
        }
    },
    isRepeatable: false
};

public __Directive deprecated = {
    name: DEPRECATED_DIR,
    locations: [ FIELD_DEFINITION, ARGUMENT_DEFINITION, ENUM_VALUE, INPUT_FIELD_DEFINITION ],
    description: "Marks the field, argument, input field or enum value as deprecated",
    args: {
        "reason": {
            name: "reason",
            description: "The reason for the deprecation",
            'type: gql_String,
            defaultValue: "No longer supported"
        }
    },
    isRepeatable: false
};

public __Directive specifiedBy = {
    name: SPECIFIED_BY_DIR,
    locations: [ SCALAR ],
    description: "Exposes a URL that specifies the behaviour of this scalar.",
    args: {
        "url": {
            name: "url",
            description: "The URL that specifies the behaviour of this scalar.",
            'type: {
                kind: NON_NULL,
                ofType: gql_String
            }
        }
    },
    isRepeatable: false
};

public __Directive skip = {
    name: SKIP_DIR,
    locations: [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
    description: "Directs the executor to skip this field or fragment when the `if` argument is true.",
    args: {
        "if": {
            name: "if",
            description: "Skipped when true.",
            'type: {
                kind: NON_NULL,
                ofType: gql_Boolean
            }
        }
    },
    isRepeatable: false
};