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

public type Datasource isolated client object {

    isolated resource function get supergraphs() returns Supergraph[]|Error;

    isolated resource function get supergraphs/[string version]() returns Supergraph|Error;

    isolated resource function get supergraphs/[string version]/subgraphs() returns Subgraph[]|Error;

    isolated resource function post supergraphs(SupergraphInsert data) returns Error?;

    isolated resource function put supergraphs/[string version](SupergraphUpdate data) returns Error?;

    isolated resource function get subgraphs(string? name = ()) returns Subgraph[]|Error;

    isolated resource function get subgraphs/[string name]/[string version]() returns Subgraph|Error;

    isolated resource function post subgraphs(SubgraphInsert data) returns Subgraph|Error;

};
