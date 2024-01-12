// Copyright (c) 2024 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import graphql_schema_registry.parser;
import ballerina/lang.regexp;

const string FIELDSET_TYPE = "FieldSet";
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
const string EXTENSION_FIELD = "extension";
const string IS_INTERFACE_OBJECT_FIELD = "isInterfaceObject";
const string REQUIRES_FIELD = "requires";
const string PROVIDES_FIELD = "provides";
const string OVERRIDE_FIELD = "override";
const string USED_OVERRIDDEN_FIELD = "usedOverridden";
const string AS_FIELD = "as";
const string FOR_FIELD = "for";
const string IMPORT_FIELD = "import";

enum LinkPurpose {
    EXECUTION,
    SECURITY
}

const FEDERATION_SPEC_IDENTITY_URL = "https://specs.apollo.dev/federation";
const FEDERATION_VERSIONS = "v2.0";
const FEDERATION_SPEC_URL = "https://specs.apollo.dev/federation/v2.0";
const LINK_SPEC_URL = "https://specs.apollo.dev/link/v1.0";
const JOIN_SPEC_URL = "https://specs.apollo.dev/join/v0.3";

type FEDERATION_SUBGRAPH_IGNORE_TYPES LINK_IMPORT_TYPE | LINK_PURPOSE_TYPE | JOIN_FIELDSET_TYPE | JOIN_GRAPH_TYPE | FIELDSET_TYPE;

type FEDERATION_SUBGRAPH_IGNORE_DIRECTIVES LINK_DIR;

type FEDERATION_FIELD_TYPES _SERVICE_FIELD_TYPE;

type FEDERATION_SUPERGRAPH_DIRECTIVES LINK_DIR | JOIN_ENUMVALUE_DIR | JOIN_FIELD_DIR | JOIN_GRAPH_DIR | JOIN_IMPLEMENTS_DIR | JOIN_TYPE_DIR | JOIN_UNION_MEMBER_DIR;

type FEDERATION_SUPERGRAPH_TYPES parser:_SERVICE_TYPE | LINK_IMPORT_TYPE | JOIN_FIELDSET_TYPE | LINK_PURPOSE_TYPE | JOIN_GRAPH_TYPE;

isolated function getFederationTypes(map<parser:__Type> types) returns map<parser:__Type>|InternalError {
    
    parser:__Type _Service = {
        name: parser:_SERVICE_TYPE,
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
            { name: SECURITY, description: "`SECURITY` features provide metadata necessary to securely resolve fields." },
            { name: EXECUTION, description: "`EXECUTION` features provide metadata necessary for operation execution." }
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

isolated function getFederationDirectives(map<parser:__Type> types) returns map<parser:__Directive> {
    parser:__Directive link = parser:createDirective(
        LINK_DIR,
        (),
        [ parser:SCHEMA ],
        {
            [URL_FIELD]: { name: URL_FIELD, 'type: types.get(parser:STRING) },
            [AS_FIELD]: { name: AS_FIELD, 'type: types.get(parser:STRING) },
            [FOR_FIELD]: { name: FOR_FIELD, 'type: types.get(LINK_PURPOSE_TYPE) },
            [IMPORT_FIELD]: { name: IMPORT_FIELD, 'type: parser:wrapType(types.get(LINK_IMPORT_TYPE), parser:LIST) }
        },
        true
    );
    parser:__Directive join__enumValue = parser:createDirective(
        JOIN_ENUMVALUE_DIR,
        (),
        [ parser:ENUM_VALUE ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL)}
        },
        true
    );
    parser:__Directive join__field = parser:createDirective(
        JOIN_FIELD_DIR,
        (),
        [ parser:FIELD_DEFINITION, parser:INPUT_FIELD_DEFINITION ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: types.get(JOIN_GRAPH_TYPE) },
            [REQUIRES_FIELD]: { name: REQUIRES_FIELD, 'type: types.get(JOIN_FIELDSET_TYPE) },
            [PROVIDES_FIELD]: { name: PROVIDES_FIELD, 'type: types.get(JOIN_FIELDSET_TYPE) },
            [TYPE_FIELD]: { name: TYPE_FIELD, 'type: types.get(parser:STRING) },
            [EXTERNAL_FIELD]: { name: EXTERNAL_FIELD, 'type: types.get(parser:BOOLEAN) },
            [OVERRIDE_FIELD]: { name: OVERRIDE_FIELD, 'type: types.get(parser:STRING) },
            [USED_OVERRIDDEN_FIELD]: { name: USED_OVERRIDDEN_FIELD, 'type: types.get(parser:BOOLEAN) }
        },
        true
    );
    parser:__Directive join__graph = parser:createDirective( 
        JOIN_GRAPH_DIR,
        (),
        [ parser:ENUM_VALUE ],
        {
            [NAME_FIELD]: { name: NAME_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) },
            [URL_FIELD]: { name: URL_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) }
        },
        false
    );
    parser:__Directive join__implements = parser:createDirective( 
        JOIN_IMPLEMENTS_DIR,
        (),
        [ parser:OBJECT, parser:INTERFACE ],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            [INTERFACE_FIELD]: { name: INTERFACE_FIELD, 'type: parser:wrapType(types.get(parser:STRING), parser:NON_NULL) }
        },
        true
    );
    parser:__Directive join__type = parser:createDirective( 
        JOIN_TYPE_DIR,
        (),
        [parser:OBJECT, parser:INTERFACE, parser:UNION, parser:ENUM, parser:INPUT_OBJECT, parser:SCALAR],
        {
            [GRAPH_FIELD]: { name: GRAPH_FIELD, 'type: parser:wrapType(types.get(JOIN_GRAPH_TYPE), parser:NON_NULL) },
            [KEY_FIELD]: { name: KEY_FIELD, 'type: types.get(JOIN_FIELDSET_TYPE) },
            [EXTENSION_FIELD]: { name: EXTENSION_FIELD, 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: false },
            [RESOLVABLE_FIELD]: { name: RESOLVABLE_FIELD, 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: true },
            [IS_INTERFACE_OBJECT_FIELD]: { name: IS_INTERFACE_OBJECT_FIELD, 'type: parser:wrapType(types.get(parser:BOOLEAN), parser:NON_NULL), defaultValue: false }
        },
        true
    );
    parser:__Directive join__unionMember = parser:createDirective( 
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

isolated function isSubgraphFederationType(string typeName) returns boolean {
    return typeName is FEDERATION_SUBGRAPH_IGNORE_TYPES;
}

isolated function isSubgraphFederationDirective(string directiveName) returns boolean {
    return directiveName is FEDERATION_SUBGRAPH_IGNORE_DIRECTIVES;
}

isolated function isSupergraphFederationDirective(string directiveName) returns boolean {
    return directiveName is FEDERATION_SUPERGRAPH_DIRECTIVES;
}

isolated function isSupergraphFederationType(string typeName) returns boolean {
    return typeName is FEDERATION_SUPERGRAPH_TYPES;
}

isolated function isFederationFieldType(string name) returns boolean {
    return name is FEDERATION_FIELD_TYPES;
}

isolated function isFederation2Subgraph(Subgraph subgraph) returns error|boolean {
    parser:__AppliedDirective[] linkDirs = getAppliedDirectives(LINK_DIR, subgraph.schema.appliedDirectives);
    boolean isFederation2Subgraph = false;
    foreach parser:__AppliedDirective linkDir in linkDirs {
        if !linkDir.args.hasKey(URL_FIELD) {
            return error InternalError(string `'@${LINK_DIR}' must contain '${URL_FIELD}'`);
        }

        anydata specUrl = linkDir.args.get(URL_FIELD).value;
        if specUrl !is string {
            return error InternalError(string `Invalid type for '${URL_FIELD}' in @'${LINK_DIR}'`);
        }
        if !specUrl.startsWith(FEDERATION_SPEC_IDENTITY_URL) {
            return error InvalidFederationSpec(string `Invalid federation specification url. Federation specification url must start with '${FEDERATION_SPEC_IDENTITY_URL}'`);
        }
        regexp:RegExp pathSeperator = re `/`;
        string[] paths = pathSeperator.split(specUrl);
        string version = paths[paths.length() - 1];
        if version !is FEDERATION_VERSIONS {
            return error InvalidFederationSpec(string `Unsupported Federation version '${version}'`);
        }

        isFederation2Subgraph = specUrl === FEDERATION_SPEC_URL;
    }
    return isFederation2Subgraph;
}