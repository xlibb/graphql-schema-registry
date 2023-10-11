__Directive include = {
    name: "include",
    locations: [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
    description: "Directs the executor to include this field or fragment only when the `if` argument is true",
    args: {
        "if": {
            name: "if",
            description: "Included when true.",
            'type: {
                kind: NON_NULL,
                ofType: Boolean
            }
        }
    },
    isRepeatable: false
};

__Directive deprecated = {
    name: "deprecated",
    locations: [ FIELD_DEFINITION, ARGUMENT_DEFINITION, ENUM_VALUE, INPUT_FIELD_DEFINITION ],
    description: "Marks the field, argument, input field or enum value as deprecated",
    args: {
        "reason": {
            name: "reason",
            description: "The reason for the deprecation",
            'type: String,
            defaultValue: "No longer supported"
        }
    },
    isRepeatable: false
};

__Directive specifiedBy = {
    name: "specifiedBy",
    locations: [ SCALAR ],
    description: "Exposes a URL that specifies the behaviour of this scalar.",
    args: {
        "url": {
            name: "url",
            description: "The URL that specifies the behaviour of this scalar.",
            'type: {
                kind: NON_NULL,
                ofType: String
            }
        }
    },
    isRepeatable: false
};

__Directive skip = {
    name: "skip",
    locations: [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
    description: "Directs the executor to skip this field or fragment when the `if` argument is true.",
    args: {
        "if": {
            name: "if",
            description: "Skipped when true.",
            'type: {
                kind: NON_NULL,
                ofType: Boolean
            }
        }
    },
    isRepeatable: false
};
