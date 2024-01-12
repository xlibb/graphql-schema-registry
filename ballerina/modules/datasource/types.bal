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

public type Supergraph record {|
    readonly string version;
    string schema;
    string apiSchema;
|};

public type SubgraphId record {|
    readonly string version;
    readonly string name;
|};

public type Subgraph record {|
    *SubgraphId;
    string url;
    string schema;
|};

public type SubgraphInsert record {|
    readonly string name;
    string url;
    string schema;
|};

public type SupergraphInsert record {|
    *Supergraph;
    SubgraphId[] subgraphs;
|};

public type SupergraphUpdate record {|
    *Supergraph;
    SubgraphId[] subgraphs;
|};