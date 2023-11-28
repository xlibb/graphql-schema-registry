import graphql_schema_registry.parser;

isolated function createSchema() returns parser:__Schema {
    [map<parser:__Type>, map<parser:__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get(parser:QUERY_TYPE)
    };
}

isolated function createObjectType(string name, map<parser:__Field> fields = {}, parser:__Type[] interfaces = [], parser:__AppliedDirective[] applied_directives = []) returns parser:__Type {
    return {
        kind: parser:OBJECT,
        name: name,
        fields: fields,
        interfaces: interfaces,
        appliedDirectives: applied_directives
    };
}

isolated function createDirective(string name, string? description, parser:__DirectiveLocation[] locations, map<parser:__InputValue> args, boolean isRepeatable) returns parser:__Directive {
    return {
        name,
        description,
        locations,
        args,
        isRepeatable
    };
}
isolated function getBuiltInDefinitions() returns [map<parser:__Type>, map<parser:__Directive>] {
    parser:__Type query_type = createObjectType(parser:QUERY_TYPE);
    map<parser:__Type> types = {};

    types[parser:BOOLEAN] = {
                                kind: parser:SCALAR,
                                name: parser:BOOLEAN,
                                description: "Built-in Boolean"
                            };
    types[parser:STRING] =  {
                                kind: parser:SCALAR,
                                name: parser:STRING,
                                description: "Built-in String"
                            };
    types[parser:FLOAT] =   {
                                kind: parser:SCALAR,
                                name: parser:FLOAT,
                                description: "Built-in Float"
                            };
    types[parser:INT] =     {
                                kind: parser:SCALAR,
                                name: parser:INT,
                                description: "Built-in Int"
                            };
    types[parser:ID] =      {
                                kind: parser:SCALAR,
                                name: parser:ID,
                                description: "Built-in ID"
                            };
    types[parser:QUERY_TYPE] = query_type;

    map<parser:__Directive> directives = getBuiltInDirectives(types);

    return [ types, directives ];
}

isolated function getBuiltInDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive include = createDirective(
        parser:INCLUDE_DIR,
        "Directs the executor to include this field or fragment only when the `if` argument is true",
        [ parser:FIELD, parser:FRAGMENT_SPREAD, parser:INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Included when true.",
                'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL)
            }
        },
        false
    );
    parser:__Directive deprecated = createDirective(
        parser:DEPRECATED_DIR,
        "Marks the field, argument, input field or enum value as deprecated",
        [ parser:FIELD_DEFINITION, parser:ARGUMENT_DEFINITION, parser:ENUM_VALUE, parser:INPUT_FIELD_DEFINITION ],
        {
            "reason": {
                name: "reason",
                description: "The reason for the deprecation",
                'type: types.get(parser:STRING),
                defaultValue: "No longer supported"
            }
        },
        false
    );
    parser:__Directive specifiedBy = createDirective(
        parser:SPECIFIED_BY_DIR,
        "Exposes a URL that specifies the behaviour of this scalar.",
        [ parser:SCALAR ],
        {
            "url": {
                name: "url",
                description: "The URL that specifies the behaviour of this scalar.",
                'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL)
            }
        },
        false
    );
    parser:__Directive skip = createDirective(
        parser:SKIP_DIR,
        "Directs the executor to skip this field or fragment when the `if` argument is true.",
        [ parser:FIELD, parser:FRAGMENT_SPREAD, parser:INLINE_FRAGMENT ],
        {
            "if": {
                name: "if",
                description: "Skipped when true.",
                'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL)
            }
        },
        false
    );

    map<parser:__Directive> directives = {};
    directives[parser:INCLUDE_DIR] = include;
    directives[parser:DEPRECATED_DIR] = deprecated;
    directives[parser:SKIP_DIR] = skip;
    directives[parser:SPECIFIED_BY_DIR] = specifiedBy;

    return directives;
}

// Get the __AppliedDirective for a given __Directive and it's arguments. Default arguments will be added automatically.
isolated function getAppliedDirectiveFromDirective(parser:__Directive directive, map<anydata> arguments) returns parser:__AppliedDirective|InternalError {
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

isolated function getDirectiveLocationsFromStrings(string[] locations) returns parser:__DirectiveLocation[]|InternalError {
    parser:__DirectiveLocation[] enumLocations = [];
    foreach string location in locations {
        enumLocations.push(check getDirectiveLocationFromString(location));
    }
    return enumLocations;
}

// Change parser to Parse DirectiveLocations as enums
isolated function getDirectiveLocationFromString(string location) returns parser:__DirectiveLocation|InternalError {
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

isolated function typeReferenceToString(parser:__Type 'type) returns string|InternalError {
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

isolated function implementInterface(parser:__Type 'type, parser:__Type interface) returns InternalError? {
    parser:__Type[]? interfaces = 'type.interfaces;
    if interfaces is parser:__Type[] {
        interfaces.push(interface);
    } else {
        return error InternalError("Provided type cannot implement interfaces");
    }
}

function applyDirective(parser:__Type|parser:__InputValue 'type, parser:__AppliedDirective appliedDirective) returns InternalError? {

}
isolated function getMutualType(parser:__Type typeA, parser:__Type typeB) returns parser:__Type? {
    if isParentType(typeA.cloneReadOnly(), typeB.cloneReadOnly()) {
        return typeA;
    } else if isParentType(typeB.cloneReadOnly(), typeA.cloneReadOnly()) {
        return typeB;
    } else if isUnionMember(typeA.cloneReadOnly(), typeB.cloneReadOnly()) {
        return typeA;
    } else if isUnionMember(typeB.cloneReadOnly(), typeA.cloneReadOnly()) {
        return typeB;
    } else {
        return ();
    }
}

isolated function isParentType(parser:__Type & readonly parent, parser:__Type & readonly child) returns boolean {
    parser:__Type[]? interfaces = child.interfaces;
    if interfaces !is () {
        // return interfaces.some(t => t.name == parent.name);
        return interfaces.some(isolated function(parser:__Type t) returns boolean {
            return t.name == parent.name;
        });
    } else {
        return false;
    }
}

isolated function isUnionMember(parser:__Type & readonly unionType, parser:__Type & readonly unionMember) returns boolean {
    parser:__Type[]? possibleTypes = unionType.possibleTypes;
    if possibleTypes !is () {
        // return possibleTypes.some(t => t.name == unionMember.name);
        return possibleTypes.some(isolated function(parser:__Type t) returns boolean {
            return t.name == unionMember.name;
        });
    } else {
        return false;
    }

}

isolated function isTypeRequired(parser:__Type 'type) returns boolean {
    return 'type.kind == parser:NON_NULL;
}

isolated function getTypesOfKind(parser:__Schema schema, parser:__TypeKind kind) returns map<parser:__Type> {
    return schema.types.filter(t => t.kind === kind);
}

isolated function isDirectiveOnDirectiveMap(parser:__Schema schema, string name) returns boolean {
    return schema.directives.hasKey(name);
}

isolated function getDirectiveFromDirectiveMap(parser:__Schema schema, string name) returns parser:__Directive {
    return schema.directives.get(name);
}

isolated function isTypeOnTypeMap(parser:__Schema schema, string name) returns boolean {
    return schema.types.hasKey(name);
}

isolated function getTypeFromTypeMap(parser:__Schema schema, string name) returns parser:__Type {
    return schema.types.get(name);
}

isolated function addTypeDefinition(parser:__Schema schema, parser:__Type 'type) returns InternalError? {
    string? typeName = 'type.name;
    if typeName is () {
        return error InternalError("Type name cannot be null");
    }
    schema.types[typeName] = 'type;
}

isolated function addDirectiveDefinition(parser:__Schema schema, parser:__Directive directive) {
    schema.directives[directive.name] = directive;
}

isolated function isDirectiveApplied(parser:__AppliedDirective[] appliedDirectives, string directiveName) returns boolean {
    boolean isApplied = false;
    foreach parser:__AppliedDirective dir in appliedDirectives {
        if dir.definition.name == directiveName {
            isApplied = true;
            break;
        }
    }
    return isApplied;
}

isolated function getAppliedDirectives(string name, parser:__AppliedDirective[] directives) returns parser:__AppliedDirective[] {
    parser:__AppliedDirective[] filter = directives.filter(a => a.definition.name === name);
    return filter;
}