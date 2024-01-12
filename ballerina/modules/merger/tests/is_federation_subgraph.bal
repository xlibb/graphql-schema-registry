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
    groups: ["merger", "federation"],
    dataProvider: dataProviderIsFederationSubgraph
}
function testIsFederationSubgraph(Subgraph subgraph, boolean|error expected) returns error? {
    error|boolean isFederation2SubgraphResult = isFederation2Subgraph(subgraph);
    if isFederation2SubgraphResult is boolean && expected is boolean {
        test:assertEquals(isFederation2SubgraphResult, expected);
    } else if isFederation2SubgraphResult is error && expected is error {
        test:assertEquals(isFederation2SubgraphResult.message(), expected.message());
    } else {
        test:assertFail("Type mismatch");
    }
}

function dataProviderIsFederationSubgraph() returns [Subgraph, boolean|error][]|error {
    Subgraph[] subgraphs = check getSubgraphsFromFileName("is_federation_subgraph", "subg");

    return [
        [subgraphs[0], true],
        [subgraphs[1], false],
        [subgraphs[2], error InvalidFederationSpec("Unsupported Federation version 'v2.3'")],
        [subgraphs[3], false],
        [subgraphs[4], true]
    ];
}