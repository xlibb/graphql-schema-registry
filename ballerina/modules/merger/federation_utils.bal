import graphql_schema_registry.parser;

function addFederationTypes(parser:__Schema supergraph_schema, Subgraph[] subgraphs) {

    map<parser:__Type> federation_types = getFederationTypes();
    foreach [string,parser:__Type] [key, value] in federation_types.entries() {
        supergraph_schema.types[key] = value;
    }

    map<parser:__Directive> federation_directives = getFederationDirectives(supergraph_schema.types);
    foreach [string,parser:__Directive] [key, value] in federation_directives.entries() {
        supergraph_schema.directives[key] = value;
    }

    if supergraph_schema.types.hasKey("join__Graph") {
        parser:__EnumValue[] enum_values = <parser:__EnumValue[]>supergraph_schema.types.get("join__Graph").enumValues;
        foreach Subgraph subgraph in subgraphs {
            parser:__AppliedDirective applied_join__graph = {
                args: {
                    "name": { value: subgraph.name, definition: parser:wrapType(supergraph_schema.types.get("String"), parser:NON_NULL) },
                    "url": { value: subgraph.url, definition: parser:wrapType(supergraph_schema.types.get("String"), parser:NON_NULL) }
                },
                definition: supergraph_schema.directives.get("join__graph")
            };
            parser:__EnumValue enum_value = {
                name: subgraph.name.toUpperAscii(),
                appliedDirectives: {
                    "join__graph": applied_join__graph
                }
            };

            enum_values.push(enum_value);
        }
    }
    
}

function getFederationTypes() returns map<parser:__Type> {
    parser:__Type link__Import = {
        name: "link__Import",
        kind: parser:SCALAR,
        description: ""
    };
    parser:__Type join__FieldSet = {
        name: "join__FieldSet",
        kind: parser:SCALAR,
        description: ""
    };

    parser:__Type link__Purpose = {
        name: "link__Purpose",
        kind: parser:ENUM,
        enumValues: [
            { name: "SECURITY", description: "`SECURITY` features provide metadata necessary to securely resolve fields." },
            { name: "EXECUTION", description: "`EXECUTION` features provide metadata necessary for operation execution." }
        ]
    };
    parser:__Type join__Graph = {
        kind: parser:ENUM,
        name: "join__Graph",
        enumValues: []
    };
    return { 
        link__Import,  join__FieldSet, link__Purpose, join__Graph
    };
}

function getFederationDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive link = createDirective(
        "link",
        (),
        [ parser:SCHEMA ],
        {
            "url": { name: "url", 'type: types.get("String") },
            "as": { name: "as", 'type: types.get("String") },
            "for": { name: "for", 'type: types.get("link__Purpose") },
            "import": { name: "import", 'type: parser:wrapType(types.get("link__Import"), parser:LIST) }
        },
        true
    );
    parser:__Directive join__enumValue = createDirective(
        "join__enumValue",
        (),
        [ parser:ENUM_VALUE ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get("join__Graph"), parser:NON_NULL)}
        },
        true
    );
    parser:__Directive join__field = createDirective(
        "join__field",
        (),
        [ parser:FIELD_DEFINITION, parser:INPUT_FIELD_DEFINITION ],
        {
            "graph": { name: "graph", 'type: types.get("join__Graph") },
            "requires": { name: "requires", 'type: types.get("join__FieldSet") },
            "provides": { name: "provides", 'type: types.get("join__FieldSet") },
            "type": { name: "type", 'type: types.get("String") },
            "external": { name: "external", 'type: types.get("Boolean") },
            "override": { name: "override", 'type: types.get("String") },
            "usedOverridden": { name: "usedOverridden", 'type: types.get("Boolean") }
        },
        true
    );
    parser:__Directive join__graph = createDirective( 
        "join__graph",
        (),
        [ parser:ENUM_VALUE ],
        {
            "name": { name: "name", 'type: parser:wrapType(types.get("String"), parser:NON_NULL) },
            "url": { name: "url", 'type: parser:wrapType(types.get("String"), parser:NON_NULL) }
        },
        false
    );
    parser:__Directive join__implements = createDirective( 
        "join__implements",
        (),
        [ parser:OBJECT, parser:INTERFACE ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get("join__Graph"), parser:NON_NULL) },
            "interface": { name: "interface", 'type: parser:wrapType(types.get("String"), parser:NON_NULL) }
        },
        true
    );
    parser:__Directive join__type = createDirective( 
        "join__type",
        (),
        [parser:SCALAR, parser:OBJECT, parser:INTERFACE, parser:UNION, parser:ENUM, parser:INPUT_OBJECT],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get("join__Graph"), parser:NON_NULL) },
            "key": { name: "key", 'type: types.get("join__FieldSet") },
            "extension": { name: "extension", 'type: parser:wrapType(types.get("Boolean"), parser:NON_NULL), defaultValue: false },
            "resolvable": { name: "resolvable", 'type: parser:wrapType(types.get("Boolean"), parser:NON_NULL), defaultValue: true },
            "isInterfaceObject": { name: "isInterfaceObject", 'type: parser:wrapType(types.get("Boolean"), parser:NON_NULL), defaultValue: false }
        },
        true
    );
    parser:__Directive join__unionMember = createDirective( 
        "join__unionMember",
        (),
        [ parser:UNION ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get("join__Graph"), parser:NON_NULL) },
            "member": { name: "member", 'type:parser:wrapType(types.get("String"), parser:NON_NULL ) }
        },
        true
    );

    return { 
        link,
        join__enumValue,
        join__field,
        join__graph,
        join__implements,
        join__type,
        join__unionMember
    };
}