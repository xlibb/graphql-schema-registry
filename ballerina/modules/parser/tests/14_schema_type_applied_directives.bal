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

@test:Config {
    groups: ["builtin"]
}
function testSchemaTypeAppliedDirectives() returns error? {
    string sdl = check getGraphqlSdlFromFile("schema_type_applied_directives");
    __Schema parsedSchema = check parseSdl(sdl, SUBGRAPH_SCHEMA);

    __Directive fooDirective = {
        name: "foo",
        locations: [ SCHEMA ],
        args: {},
        isRepeatable: true
    };
    __AppliedDirective appliedFooDir = {
        args: {},
        definition: fooDirective
    };
    __Type queryType = {
        kind: OBJECT,
        name: QUERY_TYPE,
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: []
    };
    __Type mutationType = {
        kind: OBJECT,
        name: MUTATION_TYPE,
        fields: {
            "name": { name: "name", args: {}, 'type: builtInTypes.get(STRING) }
        },
        interfaces: []
    };
    __Schema expectedSchema = {
        types: {
            [QUERY_TYPE]: queryType,
            [MUTATION_TYPE]: mutationType
        },
        directives: {
            "foo": fooDirective
        },
        queryType: queryType,
        mutationType: mutationType,
        appliedDirectives: [appliedFooDir]
    };

    test:assertEquals(parsedSchema.appliedDirectives, expectedSchema.appliedDirectives);
}