import ballerina/file;
import ballerina/io;

// Built-in Scalars
__Type Boolean = {
    kind: SCALAR,
    name: "Boolean",
    description: "Built-in Boolean"
};
__Type String = {
    kind: SCALAR,
    name: "String",
    description: "Built-in String"
};
__Type Float = {
    kind: SCALAR,
    name: "Float",
    description: "Built-in Float"
};
__Type Int = {
    kind: SCALAR,
    name: "Int",
    description: "Built-in Int"
};
__Type ID = {
    kind: SCALAR,
    name: "ID",
    description: "Built-in ID"
};

// Built-in Directives
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

type WRAPPING_TYPE NON_NULL | LIST;
isolated function wrapType(__Type 'type, WRAPPING_TYPE kind) returns __Type {
    return {
        kind: kind,
        ofType: 'type
    };
}

isolated function getGraphqlSdlFromFile(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "parser", "tests", "resources", "sdl", gqlFileName);
    return io:fileReadString(path);
}