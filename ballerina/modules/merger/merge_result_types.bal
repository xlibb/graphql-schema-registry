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

type MergeResult record {|
    Hint[] hints;
|};

type InputValueMapMergeResult record {|
    *MergeResult;
    map<parser:__InputValue> result;
|};

type FieldMapMergeResult record {|
    *MergeResult;
    map<parser:__Field> result;
|};

type EnumValuesMergeResult record {|
    *MergeResult;
    parser:__EnumValue[] result;
|};

type DescriptionMergeResult record {|
    *MergeResult;
    string? result;
|};

type DeprecationMergeResult record {|
    *MergeResult;
    boolean isDeprecated;
    string? deprecationReason = ();
|};

type DefaultValueMergeResult record {|
    *MergeResult;
    anydata? result;
|};

type PossibleTypesMergeResult record {|
    *MergeResult;
    parser:__Type[] result;
    TypeReferenceSourceGroup[] sources; 
|};

type TypeReferenceMergeResult record {|
    *MergeResult;
    parser:__Type result;
    TypeReferenceSourceGroup[] sources; 
|};

public type SupergraphMergeResult record {|
    *MergeResult;
    Supergraph result;
|};
