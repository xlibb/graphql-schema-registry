import graphql_schema_registry.parser;

const string _SERVICE_TYPE = "_Service";
const string JOIN_GRAPH_TYPE = "join__Graph";
const string JOIN_FIELDSET_TYPE = "join__FieldSet";
const string LINK_IMPORT_TYPE = "link__Import";
const string LINK_PURPOSE_TYPE = "link__Purpose";

// Directive names on supergraph
const string LINK_DIR = "link";
const string JOIN_ENUMVALUE_DIR = "join__enumValue";
const string JOIN_FIELD_DIR = "join__field";
const string JOIN_UNION_MEMBER_DIR = "join__unionMember";
const string JOIN_IMPLEMENTS_DIR = "join__implements";
const string JOIN_TYPE_DIR = "join__type";
const string JOIN_GRAPH_DIR = "join__graph";

// Directive names on subgraphs
const string KEY_DIR = "key";
const string SHAREABLE_DIR = "shareable";

const string _SERVICE_FIELD_TYPE = "_service";

const string NAME_FIELD = "name";
const string URL_FIELD = "url";
const string KEY_FIELD = "key";
const string RESOLVABLE_FIELD = "resolvable";
const string FIELDS_FIELD = "fields";
const string GRAPH_FIELD = "graph";
const string TYPE_FIELD = "type";
const string INTERFACE_FIELD = "interface";
const string UNION_MEMBER_FIELD = "member";
const string EXTERNAL_FIELD = "external";

string[] FEDERATION_SUBGRAPH_IGNORE_TYPES = [
    _SERVICE_TYPE,
    LINK_IMPORT_TYPE,
    LINK_PURPOSE_TYPE,
    parser:STRING,
    parser:BOOLEAN,
    parser:FLOAT,
    parser:INT,
    parser:ID,
    JOIN_FIELDSET_TYPE,
    JOIN_GRAPH_TYPE
];

string[] FEDERATION_SUBGRAPH_IGNORE_DIRECTIVES = [
    LINK_DIR
];

string[] FEDERATION_FIELD_TYPES = [
    _SERVICE_FIELD_TYPE
];

function getFederationTypes(map<parser:__Type> types) returns map<parser:__Type>|InternalError {
    
    parser:__Type _Service = {
        name: _SERVICE_TYPE,
        kind: parser:OBJECT,
        fields: {
            "sdl": { name: "sdl", args: {}, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) }
        }
    };
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
        link__Import,  join__FieldSet, link__Purpose, join__Graph, _Service
    };
}

function getFederationDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive link = createDirective(
        LINK_DIR,
        (),
        [ parser:SCHEMA ],
        {
            [URL_FIELD]: { name: URL_FIELD, 'type: types.get(parser:STRING) },
            "as": { name: "as", 'type: types.get(parser:STRING) },
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
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL)}
        },
        true
    );
    parser:__Directive join__field = createDirective(
        JOIN_FIELD_DIR,
        (),
        [ parser:FIELD_DEFINITION, parser:INPUT_FIELD_DEFINITION ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: types.get(JOIN_GRAPH_TYPE) },
            "requires": { name: "requires", 'type: types.get(JOIN_FIELDSET_TYPE) },
            "provides": { name: "provides", 'type: types.get(JOIN_FIELDSET_TYPE) },
            [TYPE_FIELD]: { name: TYPE_FIELD, 'type: types.get(parser:STRING) },
            "external": { name: "external", 'type: types.get(parser:BOOLEAN) },
            "override": { name: "override", 'type: types.get(parser:STRING) },
            "usedOverridden": { name: "usedOverridden", 'type: types.get(parser:BOOLEAN) }
        },
        true
    );
    parser:__Directive join__graph = createDirective( 
        JOIN_GRAPH_DIR,
        (),
        [ parser:ENUM_VALUE ],
        {
            [NAME_FIELD]: { name: NAME_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) },
            [URL_FIELD]: { name: URL_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) }
        },
        false
    );
    parser:__Directive join__implements = createDirective( 
        JOIN_IMPLEMENTS_DIR,
        (),
        [ parser:OBJECT, parser:INTERFACE ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            [INTERFACE_FIELD]: { name: INTERFACE_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) }
        },
        true
    );
    parser:__Directive join__type = createDirective( 
        JOIN_TYPE_DIR,
        (),
        [parser:SCALAR, parser:OBJECT, parser:INTERFACE, parser:UNION, parser:ENUM, parser:INPUT_OBJECT],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            "key": { name: "key", 'type: types.get(JOIN_FIELDSET_TYPE) },
            "extension": { name: "extension", 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: false },
            "resolvable": { name: "resolvable", 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: true },
            "isInterfaceObject": { name: "isInterfaceObject", 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: false }
        },
        true
    );
    parser:__Directive join__unionMember = createDirective( 
        JOIN_UNION_MEMBER_DIR,
        (),
        [ parser:UNION ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            [UNION_MEMBER_FIELD]: { name: UNION_MEMBER_FIELD, 'type:parser:wrapType(types.get(parser:STRING), parser:NON_NULL ) }
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

function isFederationFieldType(string name) returns boolean {
    return FEDERATION_FIELD_TYPES.indexOf(name) !is ();
}