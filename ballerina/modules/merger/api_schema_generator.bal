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

public isolated function getApiSchema(parser:__Schema supergraph) returns parser:__Schema {
    parser:__Schema apiSchema = supergraph.clone();
    apiSchema.appliedDirectives = removeFederationAppliedDirectives(apiSchema.appliedDirectives);
    foreach string name in apiSchema.directives.keys() {
        if isSupergraphFederationDirective(name) {
            _ = apiSchema.directives.remove(name);
        }
    }
    foreach [string, parser:__Type] [name, 'type] in apiSchema.types.entries() {
        if isSupergraphFederationType(name) || parser:isBuiltInType(name) {
            _ = apiSchema.types.remove(name);
            continue;
        }
        'type.appliedDirectives = removeFederationAppliedDirectives('type.appliedDirectives);
        removeFieldMapFederationAppliedDirectives('type.fields ?: {}); 
        removeArgMapFederationAppliedDirectives('type.inputFields ?: {});
        removeEnumValuesFederationAppliedDirectives('type.enumValues ?: []);
    }
    return apiSchema;
}

isolated function removeEnumValuesFederationAppliedDirectives(parser:__EnumValue[] values) {
    foreach parser:__EnumValue value in values {
        value.appliedDirectives = removeFederationAppliedDirectives(value.appliedDirectives);
    }
}

isolated function removeFieldMapFederationAppliedDirectives(map<parser:__Field> fieldMap) {
    foreach parser:__Field 'field in fieldMap {
        'field.appliedDirectives = removeFederationAppliedDirectives('field.appliedDirectives);
        removeArgMapFederationAppliedDirectives('field.args);
    }
}

isolated function removeArgMapFederationAppliedDirectives(map<parser:__InputValue> argMap) {
    foreach parser:__InputValue arg in argMap {
        arg.appliedDirectives = removeFederationAppliedDirectives(arg.appliedDirectives);
    }
}

isolated function removeFederationAppliedDirectives(parser:__AppliedDirective[] directives) returns parser:__AppliedDirective[] {
    return directives.filter(d => !isSupergraphFederationDirective(d.definition.name));
}