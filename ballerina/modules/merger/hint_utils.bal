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

isolated function appendHints(Hint[] newHints, Hint[] mergeHints, string? location = ()) {
    if location !is () {
        addHintsLocation(mergeHints, location);
    }
    newHints.push(...mergeHints);
}

isolated function addHintsLocation(Hint[] hints, string location) {
    foreach Hint hint in hints {
        addHintLocation(hint, location);
    }
}

isolated function addHintLocation(Hint hint, string location) {
    hint.location.unshift(location);
}

public isolated function printHints(Hint[] hints) returns string[] {
    string[] hintMessages = [];
    foreach Hint hint in hints {
        hintMessages.push(printHint(hint));
    }
    return hintMessages;
}

public isolated function filterHints(string[] relevantSubgraphs, Hint[] hints) returns Hint[] {
    Hint[] filteredHints = [];
    foreach string subgraph in relevantSubgraphs {
        foreach Hint hint in hints {
            if isHintRelevant(hint, subgraph) {
                filteredHints.push(hint);
            }
        }
    }
    return filteredHints;
}

isolated function isHintRelevant(Hint hint, string subgraph) returns boolean {
    foreach HintDetail detail in hint.details {
        if detail.consistentSubgraphs.some(s => s == subgraph) || detail.inconsistentSubgraphs.some(s => s == subgraph) {
            return true;
        }
    }
    return false;
}

isolated function printHint(Hint hint) returns string {
    string message = string `${hint.code}: `;
    string location = string:'join(".", ...hint.location);
    match hint.code {
        INCONSISTENT_DESCRIPTION => {
            message += string `Element "${location}" has inconsistent descriptions across subgraphs.` + "\n";
            foreach HintDetail detail in hint.details {
                message += string `In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, the description is,`;
                message += "\n\"\"\"\n" + detail.value.toString() + "\n\"\"\"\n";
            }
        }
        INCONSISTENT_ARGUMENT_PRESENCE => {
            HintDetail detail = hint.details[0];
            message += string `Optional argument "${detail.value.toString()}" on "${location}" will not be included in the supergraph as it does not appear in all subgraphs: `;
            message += string `It is defined in subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)} but not in subgraph(s) ${printSubgraphs(detail.inconsistentSubgraphs)}`;
        }
        INCONSISTENT_TYPE_FIELD => {
            HintDetail detail = hint.details[0];
            message += string `Field "${location}" of non-entity object type "${hint.location[0]}" is defined in some but not all subgraphs that define "${hint.location[0]}": `;
            message += string `"${location}" is defined in subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)} but not in subgraph(s) ${printSubgraphs(detail.inconsistentSubgraphs)}`;
        }
        INCONSISTENT_BUT_COMPATIBLE_OUTPUT_TYPE => {
            message += string `Type of field "${location}" is inconsistent but compatible across subgraphs.`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, the output type is "${detail.value.toString()}".`;
            }
        }
        INCONSISTENT_BUT_COMPATIBLE_INPUT_TYPE => {
            message += string `Type of input field "${location}" is inconsistent but compatible across subgraphs.`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, the input type is "${detail.value.toString()}".`;
            }
        }
        INCONSISTENT_UNION_MEMBER => {
            HintDetail detail = hint.details[0];
            message += string `Union type "${location}" includes member type "${detail.value.toString()}" in some but not all defining subgraphs: "${detail.value.toString()}" is defined in subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)} but not in subgraph(s) ${printSubgraphs(detail.inconsistentSubgraphs)}.`;
        }
        INCONSISTENT_DEFAULT_VALUE_PRESENCE => {
            message += string `Input field "${location}" has inconsistent default values across subgraphs:`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, `;
                message += detail.value is () || detail.value == "" ? string `no default value is defined.` : string `the default value is '${detail.value.toString()}'.`;
            }
        }
        INVALID_FIELD_SHARING => {
            message += string `Non-shareable field "${location}" is resolved from multiple subgraphs: `;
            HintDetail detail = hint.details[0];
            message += string `It is resolved from subgraph(s) ${printSubgraphs([...detail.consistentSubgraphs, ...detail.inconsistentSubgraphs])}. `;
            message += string `And defined as non-shareable in ${printSubgraphs(detail.inconsistentSubgraphs)}`;
        }
        TYPE_KIND_MISMATCH => {
            message += string `Type "${location}" has mismatched kind:`;
            foreach HintDetail detail in hint.details {
                message += string ` It is defined as ${detail.value.toString()} in subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}.`;
            }
        }
        OUTPUT_TYPE_MISMATCH => {
            message += string `Type of field "${location}" is inconsistent across subgraphs.`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, the output type is "${detail.value.toString()}".`;
            }
        }
        INPUT_TYPE_MISMATCH => {
            message += string `Type of input field "${location}" is inconsistent across subgraphs.`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, the input type is "${detail.value.toString()}".`;
            }
        }
        REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH => {
            HintDetail detail = hint.details[0];
            message += string `Input field "${detail.value.toString()}" of "${location}" is required in some subgraphs but does not appear in all subgraphs: `;
            message += string `It is required in subgraph(s) ${printSubgraphs([...detail.consistentSubgraphs])}. `;
            message += string `But does not appear in subgraph(s) ${printSubgraphs(detail.inconsistentSubgraphs)}`;
        }
        DEFAULT_VALUE_MISMATCH => {
            message += string `Input field "${location}" has incompatible default values across subgraphs:`;
            foreach HintDetail detail in hint.details {
                message += string ` In subgraph(s) ${printSubgraphs(detail.consistentSubgraphs)}, `;
                message += detail.value is () || detail.value == "" ? string `no default value is defined.` : string `the default value is '${detail.value.toString()}'.`;
            }
        }
        ENUM_VALUE_MISMATCH => {
            HintDetail detail = hint.details[0];
            message += string `Enum type "${location}" is used as both input and output. But value "${detail.value.toString()}" is not defined in all subgraphs defining "${location}": `;
            message += string `"${detail.value.toString()}" is defined in subgraph(s) ${printSubgraphs([...detail.consistentSubgraphs])}. `;
            message += string `But not subgraph(s) ${printSubgraphs(detail.inconsistentSubgraphs)}`;
        }
    }
    return message;
}
