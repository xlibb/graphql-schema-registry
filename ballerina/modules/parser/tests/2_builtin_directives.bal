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
    groups: ["builtin", "directives"],
    dataProvider:  dataProviderBuiltInDirectives
}
function testBuiltInDirectives(__Directive expectedDirective) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
}

function dataProviderBuiltInDirectives() returns [__Directive][] {
    return [ 
        [builtInDirectives.get(DEPRECATED_DIR)],
        [builtInDirectives.get(SKIP_DIR)],
        [builtInDirectives.get(INCLUDE_DIR)],
        [builtInDirectives.get(SPECIFIED_BY_DIR)]
    ];
}
