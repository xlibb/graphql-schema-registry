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

import ballerina/graphql;
import graphql_schema_registry.merger;
import graphql_schema_registry.parser;
import graphql_schema_registry.registry;

type ErrorDetail record {|
    string message;
    anydata details;
|};

isolated function returnErrors(graphql:Context ctx, graphql:Field 'field, error[] errors) returns error? {
    ErrorDetail[] errorDetails = errors.map(e => { 
        message: e.message(),
        details: check e.detail().ensureType(anydata)
    });

    string message;
    if errors is merger:MergeError[] { 
        message = "Supergraph composition error";
    } else if errors is parser:SchemaError[] { 
        message = "Invalid GraphQL";
    } else if errors is registry:OperationCheckError[] { 
        message = "Operation causes breaking changes";
    } else {
        message = "Error";
    }

    graphql:ErrorDetail errorDetail = {
        message: message,
        locations: ['field.getLocation()],
        path: 'field.getPath(),
        extensions: {
            errors: errorDetails
        }
    };
    graphql:__addError(ctx, errorDetail);
}