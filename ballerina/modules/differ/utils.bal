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

// TODO: Use exporter function for this. Also make exporter non-class module because there is no reason to make it a class
isolated function getTypeReferenceAsString(parser:__Type 'type) returns string|Error {
    string? typeName = 'type.name;
    if 'type.kind == parser:LIST {
        return "[" + check getTypeReferenceAsString(<parser:__Type>'type.ofType) + "]";
    } else if 'type.kind == parser:NON_NULL {
        return check getTypeReferenceAsString(<parser:__Type>'type.ofType) + "!";
    } else if typeName is string {
        return typeName;
    } else {
        return error Error("Invalid type reference");
    }
}