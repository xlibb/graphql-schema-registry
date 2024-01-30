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

import ballerina/file;
import ballerina/io;

function getSchemaSdl(string fileName) returns string|error {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "exporter", "tests", "resources", gqlFileName);
    string sdl = check io:fileReadString(path);
    return sdl;
}

function writeSchemaSdl(string fileName, string content) returns error? {
    string gqlFileName = string `${fileName}.graphql`;
    string path = check file:joinPath("modules", "exporter", "tests", "resources", gqlFileName);
    check io:fileWriteString(path, content);
}
