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

import ballerina/io;
import ballerina/file;

final __Schema emptySchema = createSchema();
final map<__Type> builtInTypes = emptySchema.types;
final map<__Directive> builtInDirectives = emptySchema.directives;

isolated function getGraphqlSdlFromFile(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "parser", "tests", "resources", "sdl", gqlFileName);
    return io:fileReadString(path);
}

isolated function parseSdl(string sdl, ParsingMode mode = SCHEMA) returns __Schema|error {
    Parser parser = new(sdl, mode);
    __Schema|SchemaError[] parsedSchema = parser.parse();
    if parsedSchema is SchemaError[] {
        return getSchemaErrorsAsError(parsedSchema);
    }
    return parsedSchema;
}
