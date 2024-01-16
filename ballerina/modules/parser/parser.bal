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

import ballerina/jballerina.java;

public isolated class Parser {

    private final handle jObj;

    public isolated function init(string schema, ParsingMode mode) {
        self.jObj = newParser(schema, mode);
    }

    public isolated function parse() returns __Schema|SchemaError[] {
        __Schema|error[] parseResult = parse(self.jObj);
        if parseResult is error[] {
            return parseResult.map(e => error SchemaError(e.message()));
        }
        return parseResult;
    }

}

public enum ParsingMode {
    SCHEMA,
    SUBGRAPH_SCHEMA,
    SUPERGRAPH_SCHEMA
}

isolated function newParser(string schema, string modeStr) returns handle = @java:Constructor {
    'class: "io.xlibb.schemaregistry.Parser"
} external;

isolated function parse(handle jObj) returns __Schema|error[] = @java:Method {
    'class: "io.xlibb.schemaregistry.Parser"
} external;
