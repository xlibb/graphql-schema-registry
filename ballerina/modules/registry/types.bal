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
import graphql_schema_registry.differ;
import graphql_schema_registry.merger;

public type Supergraph record {|
    string schemaSdl;
    string apiSchemaSdl;
    string version;
    Subgraph[] subgraphs;
|};

public type CompositionResult record {|
    *Supergraph;
    string[] hints;
    differ:SchemaDiff[] diffs;
|};

public type ComposedSupergraphSchemas record {|
    parser:__Schema schema;
    parser:__Schema apiSchema;
    string schemaSdl;
    string apiSchemaSdl;
    merger:Hint[] hints;
|};

public type Subgraph record {|
    string name;
    string url;
    string schema;
|};

type DiffResult record {|
    string version;
    differ:SchemaDiff[] diffs;
|};