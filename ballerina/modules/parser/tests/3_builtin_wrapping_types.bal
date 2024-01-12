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
    groups: ["builtin", "types", "wrapping"],
    dataProvider: dataProviderWrappingTypes
}
function testBuiltInWrappingTypes(string fileName, string fieldName, __Type expectedWrappingType) returns error? {
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    map<__Field>? fields = parsedSchema.queryType.fields;
    if (fields != ()) {
        test:assertEquals(fields.get(fieldName).'type, expectedWrappingType);
    }
}

function dataProviderWrappingTypes() returns [string, string, __Type][] {
    return [ 
        [
            "wrapping_types_list",
            "list", 
            wrapType(builtInTypes.get(STRING), LIST)
        ],
        [
            "wrapping_types_nonnull",
            "nonnull",
            wrapType(builtInTypes.get(STRING), NON_NULL)
        ],
        [
            "wrapping_types_list_of_nonnull",
            "list_of_nonnull",
            wrapType(wrapType(builtInTypes.get(STRING), NON_NULL), LIST)
        ],
        [
            "wrapping_types_nonnull_list_of_nonnull",
            "nonnull_list_of_nonnull",
            wrapType(wrapType(wrapType(builtInTypes.get(STRING), NON_NULL), LIST), NON_NULL)
        ],
        [
            "wrapping_types_list_of_list_of_list",
            "list_of_list_of_list",
            wrapType(wrapType(wrapType(builtInTypes.get(STRING), LIST), LIST), LIST)
        ]
     ];
}