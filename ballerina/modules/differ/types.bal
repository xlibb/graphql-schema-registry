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

type ComparisonResult record {|
    string[] added;
    string[] removed;
    string[] common;
|};

public type SchemaDiff record {|
    DiffSeverity severity;
    DiffAction action;
    DiffSubject subject;
    string[] location;
    string? value;
    string? fromValue;
    string? toValue;
|};

public enum TypeKind {
    OBJECT,
    INTERFACE,
    FIELD,
    ARGUMENT,
    INPUT_OBJECT,
    INPUT_FIELD,
    UNION,
    ENUM,
    ENUM_VALUE,
    SCALAR
}

public enum DiffSeverity {
    BREAKING,
    DANGEROUS,
    SAFE
}

public enum DiffAction {
    ADDED,
    REMOVED,
    CHANGED
}

public enum DiffSubject {
    DIRECTIVE,
    DIRECTIVE_DESCRIPTION,
    TYPE,
    TYPE_KIND,
    TYPE_DESCRIPTION,
    FIELD,
    FIELD_DEPRECATION,
    FIELD_TYPE,
    FIELD_DESCRIPTION,
    ARGUMENT,
    ARGUMENT_TYPE,
    ARGUMENT_DEFAULT,
    ARGUMENT_DESCRIPTION,
    INPUT_FIELD,
    INPUT_FIELD_DEFAULT,
    INPUT_FIELD_TYPE,
    INPUT_FIELD_DESCRIPTION,
    ENUM,
    ENUM_DESCRIPTION,
    ENUM_DEPRECATION,
    INTERFACE_IMPLEMENTATION,
    UNION_MEMBER
}

type InputType INPUT_FIELD | ARGUMENT;
