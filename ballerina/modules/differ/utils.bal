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

import graphql_schema_registry.parser;

isolated function appendDiffs(SchemaDiff[] newDiffs, SchemaDiff[] oldDiffs, string? location = ()) {
    addDiffsLocation(oldDiffs, location);
    newDiffs.push(...oldDiffs);
}

isolated function addDiffsLocation(SchemaDiff[] diffs, string? location = ()) {
    if location !is () {
        foreach SchemaDiff diff in diffs {
            addDiffLocation(diff, location);
        }
    }
}

isolated function addDiffLocation(SchemaDiff diff, string location) {
    diff.location.unshift(location);
}


isolated function listContains(string value, string[] values) returns boolean {
    return values.indexOf(value) !is ();
}

isolated function createDiff(DiffAction action, DiffSubject subject, DiffSeverity severity, string[] location = [], 
                                string? value = (), string? fromValue = (), string? toValue = ()) returns SchemaDiff {
    return {
        action,
        subject,
        severity,
        location,
        value,
        fromValue,
        toValue
    };
}

isolated function getTypeReferenceAsString(parser:__Type 'type) returns string|Error {
    string? typeName = 'type.name;
    if 'type.kind == parser:LIST {
        return string `[${check getTypeReferenceAsString(<parser:__Type>'type.ofType)}]`;
    } else if 'type.kind == parser:NON_NULL {
        return string `${check getTypeReferenceAsString(<parser:__Type>'type.ofType)}!`;
    } else if typeName is string {
        return typeName;
    } else {
        return error Error("Invalid type reference");
    }
}

public isolated function getDiffMessage(SchemaDiff diff) returns string {
    return string `${diff.severity}: ${getDiffActionAsString(diff) ?: ""}`;
}

isolated function getDiffActionAsString(SchemaDiff diff) returns string? {
    string location = string:'join(".", ...diff.location);
    match diff.action {
        ADDED => { return string `Added '${diff.value.toString()}' to ${location.toString()}.`; }
        REMOVED => { return string `Removed '${diff.value.toString()}' from ${location.toString()}.`; }
        CHANGED => { return string `Changed value of '${location}' from '${diff.fromValue.toString()}' to '${diff.toValue.toString()}'.`; }
        _ => { return (); }
    }
}
