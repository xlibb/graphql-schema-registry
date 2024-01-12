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

public type __Schema record {|
    string? description = ();
    map<__Type> types;
    __Type queryType;
    __Type? mutationType = ();
    __Type? subscriptionType = ();
    map<__Directive> directives;
    __AppliedDirective[] appliedDirectives = [];
|};

public type __Type record {|
    __TypeKind kind;
    string? name = ();
    string? description = ();
    map<__Field>? fields = ();
    __AppliedDirective[] appliedDirectives = [];
    __Type[]? interfaces = ();
    __Type[]? possibleTypes = ();
    __EnumValue[]? enumValues = ();
    map<__InputValue>? inputFields = ();
    __Type? ofType = ();
|};

public type __Directive record {|
    string name;
    string? description = ();
    __DirectiveLocation[] locations = [];
    map<__InputValue> args;
    boolean isRepeatable;
|};

public type __AppliedDirective record {
    map<__AppliedDirectiveInputValue> args;
    __Directive definition;
};

public type __AppliedDirectiveInputValue record {
    anydata? value = ();
    __Type definition;
};

public enum __DirectiveLocation {
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT,
    VARIABLE_DEFINITION,
    SCHEMA,
    SCALAR,
    OBJECT,
    FIELD_DEFINITION,
    ARGUMENT_DEFINITION,
    INTERFACE,
    UNION,
    ENUM,
    ENUM_VALUE,
    INPUT_OBJECT,
    INPUT_FIELD_DEFINITION
}

public enum __TypeKind {
    SCALAR,
    OBJECT,
    INTERFACE,
    UNION,
    ENUM,
    INPUT_OBJECT,
    LIST,
    NON_NULL
}

public type __Field record {|
    string name;
    string? description = ();
    map<__InputValue> args;
    __AppliedDirective[] appliedDirectives = [];
    __Type 'type;
    boolean isDeprecated = false;
    string? deprecationReason = ();
|};

public type __InputValue record {|
    string name;
    string? description = ();
    __AppliedDirective[] appliedDirectives = [];
    __Type 'type;
    anydata? defaultValue = ();
|};

public type __EnumValue record {|
    string name;
    string? description = ();
    __AppliedDirective[] appliedDirectives = [];
    boolean isDeprecated = false;
    string? deprecationReason = ();
|};