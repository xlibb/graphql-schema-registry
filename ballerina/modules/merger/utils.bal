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

public isolated function printSubgraphs(string[] subgraphs) returns string {
    if subgraphs.length() == 0 {
        return "";
    } else if subgraphs.length() == 1 {
        return string `"${subgraphs[0]}"`;
    } else {
        string[]|error clonedSubgraphs = subgraphs.cloneWithType();
        if clonedSubgraphs is error {
            return "";
        }
        string last = clonedSubgraphs.pop();
        return string `${string:'join(", ", ...clonedSubgraphs.map(s => string `"${s}"`))} and "${last}"`;
    }
}