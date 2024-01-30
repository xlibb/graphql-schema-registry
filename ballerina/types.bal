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

import graphql_schema_registry.registry;
import graphql_schema_registry.differ;

public type SubgraphInput record {|
    *registry:Subgraph;
|};

public distinct service isolated class Subgraph {
    private final readonly & registry:Subgraph schemaRecord;

    isolated function init(registry:Subgraph schema) {
        self.schemaRecord = schema.cloneReadOnly();
    }

    isolated resource function get name() returns string {
        return self.schemaRecord.name;
    }

    isolated resource function get schema() returns string {
        return self.schemaRecord.schema;
    }
}

public distinct service isolated class Supergraph {
    private final readonly & registry:Supergraph schemaRecord;

    isolated function init(registry:Supergraph schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    isolated resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.map(s => new Subgraph(s));
    }

    isolated resource function get schema() returns string {
        return self.schemaRecord.schemaSdl;
    }

    isolated resource function get version() returns string|error {
        return self.schemaRecord.version;
    }

    isolated resource function get apiSchema() returns string {
        return self.schemaRecord.apiSchemaSdl;
    }

}

public distinct service isolated class CompositionResult {
    private final readonly & registry:CompositionResult schemaRecord;

    isolated function init(registry:CompositionResult schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    isolated resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.map(s => new Subgraph(s));
    }

    isolated resource function get schema() returns string {
        return self.schemaRecord.schemaSdl;
    }

    isolated resource function get version() returns string|error {
        return self.schemaRecord.version;
    }

    isolated resource function get apiSchema() returns string {
        return self.schemaRecord.apiSchemaSdl;
    }

    isolated resource function get hints() returns string[] {
        return self.schemaRecord.hints;
    }

    isolated resource function get diffs() returns differ:SchemaDiff[] {
        return self.schemaRecord.diffs;
    }
}
