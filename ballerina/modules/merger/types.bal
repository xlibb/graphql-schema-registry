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

public type Subgraph record {|
    string name;
    string url;
    parser:__Schema schema;
    boolean isFederation2Subgraph = false;
|};

public type Supergraph record {|
    parser:__Schema schema;
    Subgraph[] subgraphs;
|};

public type HintDetail record {|
    anydata value;
    string[] consistentSubgraphs;
    string[] inconsistentSubgraphs;
|};

public type Hint record {|
    string code;
    string[] location;
    HintDetail[] details;
|};

public type EnumTypeUsage record {|
    boolean isUsedInOutputs;
    boolean isUsedInInputs;
|};

public type EntityStatus record {|
    boolean isEntity;
    boolean isResolvable;
    string[] keyFields;
|};