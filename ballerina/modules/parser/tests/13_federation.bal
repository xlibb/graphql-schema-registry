import ballerina/test;

__Type field_set_scalar = {
    name: "FieldSet",
    kind: SCALAR,
    description: ""
};
__Type _Any_scalar = {
    name: "_Any",
    kind: SCALAR,
    description: ""
};
__Type federation_Scope_scalar = {
    name: "federation__Scope",
    kind: SCALAR,
    description: ""
};

@test:Config {
    groups: ["federation"]
}
function testFederationBuiltin() returns error? {
    string sdl = check getGraphqlSdlFromFile("federation_builtin");
    Parser parser = new(sdl, SUBGRAPH_SCHEMA);
    __Schema parsedSchema = check parser.parse();

    __Type link__Import_scalar = {
        kind: SCALAR,
        name: "link__Import",
        description: ""
    };
    __Type link__Purpose_enum = {
        kind: ENUM,
        name: "link__Purpose",
        enumValues: [
            { name: "SECURITY" },
            { name: "EXECUTION" }
        ]
    };
    __Type _service_type = {
        name: "_Service",
        kind: OBJECT,
        fields: {
            "sdl": { name: "sdl", args: {}, 'type: wrapType(gql_String, NON_NULL) }
        },
        interfaces: []
    };
    __Directive link_directive = {
        name: "link",
        locations: [ SCHEMA ],
        args: {
            "url": { name: "url", 'type: wrapType(gql_String, NON_NULL) },
            "as": { name: "as", 'type: gql_String },
            "for": { name: "for", 'type: link__Purpose_enum },
            "import": { name: "import", 'type: wrapType(link__Import_scalar, LIST) }
        },
        isRepeatable: true
    };
    __Field _service_extended_field = {
        name: "_service",
        args: {},
        'type: wrapType(_service_type, NON_NULL)
    };

    test:assertEquals(parsedSchema.types.get("link__Import"), link__Import_scalar);
    test:assertEquals(parsedSchema.types.get("link__Purpose"), link__Purpose_enum);
    test:assertEquals(parsedSchema.directives.get("link"), link_directive);

    map<__Field>? fields = parsedSchema.queryType.fields;
    if (fields != ()) {
        test:assertEquals(fields.get("_service"), _service_extended_field);
    } else {
        test:assertFail("_service Query extension not found");
    }
}

@test:Config {
    groups: ["federation", "imports"],
    dataProvider: dataProviderFederationImports
}
function testFederationImports(__Directive expectedDirective) returns error? {
    string sdl = check getGraphqlSdlFromFile("federation_imports");
    Parser parser = new(sdl, SUBGRAPH_SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
}

function dataProviderFederationImports() returns __Directive[][] {
    return [
        [{
            name: "external",
            locations: [ FIELD_DEFINITION, OBJECT ],
            args: {},
            isRepeatable: false
        }],
        [{
            name: "requires",
            locations: [ FIELD_DEFINITION ],
            args: {
                "fields": { name: "fields", 'type: wrapType(field_set_scalar, NON_NULL) }
            },
            isRepeatable: false
        }],
        [{
            name: "provides",
            locations: [ FIELD_DEFINITION ],
            args: {
                "fields": { name: "fields", 'type: wrapType(field_set_scalar, NON_NULL) }
            },
            isRepeatable: false
        }],
        [{
            name: "key",
            locations: [ OBJECT, INTERFACE ],
            args: {
                "fields": { name: "fields", 'type: wrapType(field_set_scalar, NON_NULL) },
                "resolvable": { name: "resolvable", 'type: gql_Boolean, defaultValue: true }
            },
            isRepeatable: true
        }],
        [{
            name: "shareable",
            locations: [ OBJECT, FIELD_DEFINITION ],
            args: {},
            isRepeatable: true
        }],
        [{
            name: "inaccessible",
            locations: [FIELD_DEFINITION , OBJECT , INTERFACE , UNION , ARGUMENT_DEFINITION , SCALAR 
                                                    , ENUM , ENUM_VALUE , INPUT_OBJECT , INPUT_FIELD_DEFINITION],
            args: {},
            isRepeatable: false
        }],
        [{
            name: "tag",
            locations: [FIELD_DEFINITION , INTERFACE , OBJECT , UNION , ARGUMENT_DEFINITION
                                                , SCALAR , ENUM , ENUM_VALUE , INPUT_OBJECT , INPUT_FIELD_DEFINITION],
            args: {
                "name": { name: "name", 'type: wrapType(gql_String, NON_NULL) }
            },
            isRepeatable: true
        }],
        [{
            name: "override",
            locations: [ FIELD_DEFINITION ],
            args: {
                "from": { name: "from", 'type: wrapType(gql_String, NON_NULL) }
            },
            isRepeatable: false
        }],
        [{
            name: "composeDirective",
            locations: [ SCHEMA ],
            args: {
                "name": { name: "name", 'type: wrapType(gql_String, NON_NULL) }
            },
            isRepeatable: true
        }],
        [{
            name: "interfaceObject",
            locations: [ OBJECT ],
            args: {},
            isRepeatable: false
        }],
        [{
            name: "authenticated",
            locations: [FIELD_DEFINITION , OBJECT , INTERFACE , SCALAR , ENUM],
            args: {},
            isRepeatable: false
        }],
        [{
            name: "requiresScopes",
            locations: [FIELD_DEFINITION , OBJECT , INTERFACE , SCALAR , ENUM],
            args: {
                "scopes": { name: "scopes", 'type: wrapType(
                                                    wrapType(
                                                        wrapType(
                                                            wrapType(
                                                                wrapType(
                                                                    federation_Scope_scalar,
                                                                    NON_NULL
                                                                ), LIST
                                                            ), NON_NULL
                                                        ), LIST
                                                    ), NON_NULL
                                                   )}
            },
            isRepeatable: false
        }]
    ];
}