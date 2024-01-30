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
    groups: ["custom", "types", "scalars"],
    dataProvider: dataProviderScalarValidation
}
function testCustomScalarTypes(string filename, __Type expectedScalarType) returns error? {
    string sdl = check getGraphqlSdlFromFile(filename);
    __Schema parsedSchema = check parseSdl(sdl);

    string? typeName = expectedScalarType.name;
    if (typeName != ()) {
        test:assertEquals(parsedSchema.types[typeName], expectedScalarType);
    }
}

function dataProviderScalarValidation() returns map<[string, __Type]> {
    return { 
        "1" : ["scalars", { kind: SCALAR, name: "Email", description: "" }],
        "2" : ["scalars_with_description", { kind: SCALAR, name: "Email", description: "Email description" }]
    };
}
