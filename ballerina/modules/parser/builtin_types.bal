// Built-in Scalars
// TODO: Make built in types 'readonly'
// const cBoolean = {
//     kind: SCALAR,
//     name: BOOLEAN,
//     description: "Built-in Boolean",
//     appliedDirectives: []
// };

// public final __Type & readonly Boolean = check cBoolean.cloneWithType(__Type).cloneReadOnly();
public final __Type gql_Boolean = {
    kind: SCALAR,
    name: BOOLEAN,
    description: "Built-in Boolean"
};
public final __Type gql_String = {
    kind: SCALAR,
    name: STRING,
    description: "Built-in String"
};
public final __Type gql_Float = {
    kind: SCALAR,
    name: FLOAT,
    description: "Built-in Float"
};
public final __Type gql_Int = {
    kind: SCALAR,
    name: INT,
    description: "Built-in Int"
};
public final __Type gql_ID = {
    kind: SCALAR,
    name: ID,
    description: "Built-in ID"
};

// Built-in Directives
public final __Directive include = {
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

public final __Directive deprecated = {
    name: DEPRECATED_DIR,
    locations: [ FIELD_DEFINITION, ENUM_VALUE, ARGUMENT_DEFINITION, INPUT_FIELD_DEFINITION ],
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

public final __Directive specifiedBy = {
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

public final __Directive skip = {
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