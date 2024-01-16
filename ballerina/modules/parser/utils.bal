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

public type WRAPPING_TYPE NON_NULL | LIST;

public const INCLUDE_DIR = "include";
public const DEPRECATED_DIR = "deprecated";
public const SKIP_DIR = "skip";
public const SPECIFIED_BY_DIR = "specifiedBy";
public const INCLUDE_DIR_DESC = "Directs the executor to include this field or fragment only when the `if` argument is true";
public const DEPRECATED_DIR_DESC = "Marks the field, argument, input field or enum value as deprecated";
public const SPECIFIED_BY_DIR_DESC = "Exposes a URL that specifies the behaviour of this scalar.";
public const SKIP_DIR_DESC = "Directs the executor to skip this field or fragment when the `if` argument is true.";
public const IF_FIELD = "if";
public const REASON_FIELD = "reason";
public const URL_FIELD = "url";
public const INCLUDE_DIR_IF_DESC = "Included when true.";
public const URL_FIELD_DESC = "The URL that specifies the behaviour of this scalar.";
public const REASON_FIELD_DESC = "The reason for the deprecation";
public const SKIP_DIR_IF_DESC = "Skipped when true.";
public const REASON_FIELD_DEFAULT_VALUE = "No longer supported";

public const BOOLEAN = "Boolean";
public const STRING = "String";
public const FLOAT = "Float";
public const INT = "Int";
public const ID = "ID";
public const BOOLEAN_DESC = "Built-in Boolean";
public const STRING_DESC = "Built-in String";
public const FLOAT_DESC = "Built-in Float";
public const INT_DESC = "Built-in Int";
public const ID_DESC = "Built-in ID";
public const QUERY_TYPE = "Query";
public const MUTATION_TYPE = "Mutation";
public const SUBSCRIPTION_TYPE = "Subscription";
public const _SERVICE_TYPE = "_Service";

public type BUILT_IN_TYPES _SERVICE_TYPE | BOOLEAN | STRING | FLOAT | INT | ID;

public type ROOT_OPERATION_TYPES QUERY_TYPE | MUTATION_TYPE | SUBSCRIPTION_TYPE;

public type EXECUTABLE_DIRECTIVE_LOCATIONS QUERY | MUTATION | SUBSCRIPTION | FIELD | FRAGMENT_DEFINITION | FRAGMENT_SPREAD | INLINE_FRAGMENT;

public type BUILT_IN_DIRECTIVES INCLUDE_DIR | DEPRECATED_DIR | SKIP_DIR | SPECIFIED_BY_DIR;

public isolated function wrapType(__Type 'type, WRAPPING_TYPE kind) returns __Type {
    return {
        kind: kind,
        ofType: 'type
    };
}

public isolated function isBuiltInDirective(string directiveName) returns boolean {
    return directiveName is BUILT_IN_DIRECTIVES;
}

public isolated function isRootOperationType(string typeName) returns boolean {
    return typeName is ROOT_OPERATION_TYPES;
}

public isolated function isExecutableDirective(__Directive directive) returns boolean {
    foreach __DirectiveLocation location in directive.locations {
        return location is EXECUTABLE_DIRECTIVE_LOCATIONS;
    }
    return false;
}

public isolated function isBuiltInType(string typeName) returns boolean {
    return typeName is BUILT_IN_TYPES;
}

public isolated function createSchema() returns __Schema {
    [map<__Type>, map<__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get(QUERY_TYPE)
    };
}

public isolated function createObjectType(string name, map<__Field> fields = {}, __Type[] interfaces = [], __AppliedDirective[] applied_directives = []) returns __Type {
    return {
        kind: OBJECT,
        name: name,
        fields: fields,
        interfaces: interfaces,
        appliedDirectives: applied_directives
    };
}

public isolated function createScalarType(string name, string? description = ()) returns __Type {
    return {
        kind: SCALAR,
        name: name,
        description: description
    };
}

public isolated function createDirective(string name, string? description, __DirectiveLocation[] locations, map<__InputValue> args, boolean isRepeatable) returns __Directive {
    return {
        name,
        description,
        locations,
        args,
        isRepeatable
    };
}

public isolated function getBuiltInDefinitions() returns [map<__Type>, map<__Directive>] {
    map<__Type> types = {};

    types[BOOLEAN]  = createScalarType(BOOLEAN, BOOLEAN_DESC);
    types[STRING]   = createScalarType(STRING, STRING_DESC);
    types[FLOAT]    = createScalarType(FLOAT, FLOAT_DESC);
    types[INT]      = createScalarType(INT, INT_DESC);
    types[ID]       = createScalarType(ID, ID_DESC);

    types[QUERY_TYPE] = createObjectType(QUERY_TYPE);

    map<__Directive> directives = getBuiltInDirectives(types);

    return [ types, directives ];
}

isolated function getBuiltInDirectives(map<__Type> types) returns map<__Directive> {
    __Directive include = createDirective(
        INCLUDE_DIR,
        INCLUDE_DIR_DESC,
        [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
        {
            [IF_FIELD]: {
                name: IF_FIELD,
                description: INCLUDE_DIR_IF_DESC,
                'type: wrapType(types.get(BOOLEAN), NON_NULL)
            }
        },
        false
    );
    __Directive deprecated = createDirective(
        DEPRECATED_DIR,
        DEPRECATED_DIR_DESC,
        [ FIELD_DEFINITION, ENUM_VALUE, ARGUMENT_DEFINITION, INPUT_FIELD_DEFINITION ],
        {
            [REASON_FIELD]: {
                name: REASON_FIELD,
                description: REASON_FIELD_DESC,
                'type: types.get(STRING),
                defaultValue: REASON_FIELD_DEFAULT_VALUE
            }
        },
        false
    );
    __Directive specifiedBy = createDirective(
        SPECIFIED_BY_DIR,
        SPECIFIED_BY_DIR_DESC,
        [ SCALAR ],
        {
            [URL_FIELD]: {
                name: URL_FIELD,
                description: URL_FIELD_DESC,
                'type: wrapType(types.get(STRING), NON_NULL)
            }
        },
        false
    );
    __Directive skip = createDirective(
        SKIP_DIR,
        SKIP_DIR_DESC,
        [ FIELD, FRAGMENT_SPREAD, INLINE_FRAGMENT ],
        {
            [IF_FIELD]: {
                name: IF_FIELD,
                description: SKIP_DIR_IF_DESC,
                'type: wrapType(types.get(BOOLEAN), NON_NULL)
            }
        },
        false
    );

    map<__Directive> directives = {};
    directives[INCLUDE_DIR] = include;
    directives[DEPRECATED_DIR] = deprecated;
    directives[SKIP_DIR] = skip;
    directives[SPECIFIED_BY_DIR] = specifiedBy;

    return directives;
}

public isolated function getSchemaErrorsAsError(SchemaError[] errors) returns error {
    return error(string `Schema Errors. ${errors.map(e => e.message()).toString()}`);
}
