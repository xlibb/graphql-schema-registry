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

import ballerina/test;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "api_schema"]
}
function testApiSchema() returns error? {
    TestSchemas schemas = check getMergedAndParsedSchemas("full_schema");
    parser:__Schema apiSchema = getApiSchema(schemas.merged);
    string exportedApiSchemaSdl = check exporter:export(apiSchema);
    test:assertEquals(exportedApiSchemaSdl, check getSupergraphSdlFromFileName("full_schema_api"));
}
