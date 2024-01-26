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

import ballerina/graphql;
import ballerina/lang.runtime;
import graphql_schema_registry.registry;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import graphql_schema_registry.merger;
import graphql_schema_registry.differ;

configurable int port = 9090;

function getSchemaRegistryService(datasource:Datasource datasource) returns graphql:Service {
    graphql:Service schemaRegistryService = service object {
        private final registry:Registry registry = new(datasource);

        isolated resource function get supergraph() returns Supergraph|error {
            return new Supergraph(check self.registry.getLatestSupergraph());
        }

        isolated resource function get supergraphVersions() returns string[]|error {
            return check self.registry.getVersions();
        }

        isolated resource function get dryRun(graphql:Context context, graphql:Field 'field, SubgraphInput schema, boolean isForced = false) returns CompositionResult|error? {
            registry:CompositionResult|parser:SchemaError[]|merger:MergeError[]|registry:OperationCheckError[] result = check self.registry.dryRun(schema, isForced);
            if result is registry:CompositionResult {
                return new CompositionResult(result);
            } else {
                check returnErrors(context, 'field, result);
                return;
            }
        }

        isolated resource function get subgraph(string name) returns Subgraph|error {
            return new Subgraph(check self.registry.getSubgraphByName(name));
        }

        isolated resource function get diff(graphql:Context context, graphql:Field 'field, string newVersion, string oldVersion) returns differ:SchemaDiff[]|error {
            return check self.registry.getDiff(newVersion, oldVersion);
        }

        isolated remote function publishSubgraph(graphql:Context context, graphql:Field 'field, SubgraphInput schema, boolean isForced = false) returns CompositionResult|error? {
            registry:CompositionResult|parser:SchemaError[]|merger:MergeError[]|registry:OperationCheckError[] result = check self.registry.publishSubgraph(schema, isForced);
            if result is registry:CompositionResult {
                return new CompositionResult(result);
            } else {
                check returnErrors(context, 'field, result);
                return;
            }
        }
    };
    return schemaRegistryService;
}

public function main() returns error? {
    graphql:Listener graphqlListener = check new (port);
    graphql:Service registryService = getSchemaRegistryService(check new MongodbDatasource());
    check graphqlListener.attach(registryService);
    check graphqlListener.'start();
    runtime:registerListener(graphqlListener);
}
