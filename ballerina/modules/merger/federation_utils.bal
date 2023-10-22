import graphql_schema_registry.parser;

const string _SERVICE_TYPE = "_Service";
const string JOIN_GRAPH_TYPE = "join__Graph";
const string JOIN_FIELDSET_TYPE = "join__FieldSet";
const string LINK_IMPORT_TYPE = "link__Import";
const string LINK_PURPOSE_TYPE = "link__Purpose";

const string LINK_DIR = "link";
const string JOIN_ENUMVALUE_DIR = "join__enumValue";
const string JOIN_FIELD_DIR = "join__field";
const string JOIN_UNION_MEMBER_DIR = "join__unionMember";
const string JOIN_IMPLEMENTS_DIR = "join__implements";
const string JOIN_TYPE_DIR = "join__type";
const string JOIN_GRAPH_DIR = "join__graph";

string[] FEDERATION_SUBGRAPH_IGNORE_TYPES = [
    _SERVICE_TYPE,
    LINK_IMPORT_TYPE,
    LINK_PURPOSE_TYPE,
    STRING,
    BOOLEAN,
    FLOAT,
    INT,
    ID
];

string[] FEDERATION_SUBGRAPH_IGNORE_DIRECTIVES = [
    LINK_DIR
];

function addFederationTypes(parser:__Schema supergraph_schema, Subgraph[] subgraphs) {

    map<parser:__Type> federation_types = getFederationTypes();
    foreach [string,parser:__Type] [key, value] in federation_types.entries() {
        supergraph_schema.types[key] = value;
    }

    map<parser:__Directive> federation_directives = getFederationDirectives(supergraph_schema.types);
    foreach [string,parser:__Directive] [key, value] in federation_directives.entries() {
        supergraph_schema.directives[key] = value;
    }

    if supergraph_schema.types.hasKey(JOIN_GRAPH_TYPE) {
        parser:__EnumValue[] enum_values = <parser:__EnumValue[]>supergraph_schema.types.get(JOIN_GRAPH_TYPE).enumValues;
        foreach Subgraph subgraph in subgraphs {
            parser:__AppliedDirective applied_join__graph = {
                args: {
                    "name": { 
                        value: subgraph.name, 
                        definition: parser:wrapType(supergraph_schema.types.get(STRING), parser:NON_NULL) 
                    },
                    "url": { 
                        value: subgraph.url, 
                        definition: parser:wrapType(supergraph_schema.types.get(STRING), parser:NON_NULL) 
                    }
                },
                definition: supergraph_schema.directives.get(JOIN_GRAPH_DIR)
            };

            parser:__EnumValue enum_value = {
                name: subgraph.name.toUpperAscii(),
                appliedDirectives: [ applied_join__graph ]
            };

            enum_values.push(enum_value);
        }
    }
    
}

function getFederationTypes() returns map<parser:__Type> {
    parser:__Type link__Import = {
        name: LINK_IMPORT_TYPE,
        kind: parser:SCALAR,
        description: ""
    };
    parser:__Type join__FieldSet = {
        name: JOIN_FIELDSET_TYPE,
        kind: parser:SCALAR,
        description: ""
    };

    parser:__Type link__Purpose = {
        name: LINK_PURPOSE_TYPE,
        kind: parser:ENUM,
        enumValues: [
            { name: "SECURITY", description: "`SECURITY` features provide metadata necessary to securely resolve fields." },
            { name: "EXECUTION", description: "`EXECUTION` features provide metadata necessary for operation execution." }
        ]
    };
    parser:__Type join__Graph = {
        kind: parser:ENUM,
        name: JOIN_GRAPH_TYPE,
        enumValues: []
    };
    return { 
        link__Import,  join__FieldSet, link__Purpose, join__Graph
    };
}

function getFederationDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive link = createDirective(
        LINK_DIR,
        (),
        [ parser:SCHEMA ],
        {
            "url": { name: "url", 'type: types.get(STRING) },
            "as": { name: "as", 'type: types.get(STRING) },
            "for": { name: "for", 'type: types.get(LINK_PURPOSE_TYPE) },
            "import": { name: "import", 'type: parser:wrapType(types.get(LINK_IMPORT_TYPE), parser:LIST) }
        },
        true
    );
    parser:__Directive join__enumValue = createDirective(
        JOIN_ENUMVALUE_DIR,
        (),
        [ parser:ENUM_VALUE ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL)}
        },
        true
    );
    parser:__Directive join__field = createDirective(
        JOIN_FIELD_DIR,
        (),
        [ parser:FIELD_DEFINITION, parser:INPUT_FIELD_DEFINITION ],
        {
            "graph": { name: "graph", 'type: types.get(JOIN_GRAPH_TYPE) },
            "requires": { name: "requires", 'type: types.get(JOIN_FIELDSET_TYPE) },
            "provides": { name: "provides", 'type: types.get(JOIN_FIELDSET_TYPE) },
            "type": { name: "type", 'type: types.get(STRING) },
            "external": { name: "external", 'type: types.get(BOOLEAN) },
            "override": { name: "override", 'type: types.get(STRING) },
            "usedOverridden": { name: "usedOverridden", 'type: types.get(BOOLEAN) }
        },
        true
    );
    parser:__Directive join__graph = createDirective( 
        JOIN_GRAPH_DIR,
        (),
        [ parser:ENUM_VALUE ],
        {
            "name": { name: "name", 'type: parser:wrapType(types.get(STRING), parser:NON_NULL) },
            "url": { name: "url", 'type: parser:wrapType(types.get(STRING), parser:NON_NULL) }
        },
        false
    );
    parser:__Directive join__implements = createDirective( 
        JOIN_IMPLEMENTS_DIR,
        (),
        [ parser:OBJECT, parser:INTERFACE ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            "interface": { name: "interface", 'type: parser:wrapType(types.get(STRING), parser:NON_NULL) }
        },
        true
    );
    parser:__Directive join__type = createDirective( 
        JOIN_TYPE_DIR,
        (),
        [parser:SCALAR, parser:OBJECT, parser:INTERFACE, parser:UNION, parser:ENUM, parser:INPUT_OBJECT],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            "key": { name: "key", 'type: types.get(JOIN_FIELDSET_TYPE) },
            "extension": { name: "extension", 'type: parser:wrapType(types.get(BOOLEAN), parser:NON_NULL), defaultValue: false },
            "resolvable": { name: "resolvable", 'type: parser:wrapType(types.get(BOOLEAN), parser:NON_NULL), defaultValue: true },
            "isInterfaceObject": { name: "isInterfaceObject", 'type: parser:wrapType(types.get(BOOLEAN), parser:NON_NULL), defaultValue: false }
        },
        true
    );
    parser:__Directive join__unionMember = createDirective( 
        JOIN_UNION_MEMBER_DIR,
        (),
        [ parser:UNION ],
        {
            "graph": { name: "graph", 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            "member": { name: "member", 'type:parser:wrapType(types.get(STRING), parser:NON_NULL ) }
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

function isSubgraphFederationType(string typeName) returns boolean {
    return FEDERATION_SUBGRAPH_IGNORE_TYPES.indexOf(typeName) !is ();
}

function isSubgraphFederationDirective(string directiveName) returns boolean {
    return FEDERATION_SUBGRAPH_IGNORE_DIRECTIVES.indexOf(directiveName) !is ();
}