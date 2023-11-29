isolated function appendDiffs(SchemaDiff[] newDiffs, SchemaDiff[] oldDiffs, DiffLocation? location = ()) {
    addDiffsLocation(oldDiffs, location);
    newDiffs.push(...oldDiffs);
}

isolated function addDiffsLocation(SchemaDiff[] diffs, DiffLocation? location = ()) {
    if location !is () {
        foreach SchemaDiff diff in diffs {
            addDiffLocation(diff, location);
        }
    }
}

isolated function addDiffLocation(SchemaDiff diff, DiffLocation location) {
    diff.location.unshift(location);
}


isolated function listContains(string value, string[] values) returns boolean {
    return values.indexOf(value) !is ();
}

isolated function createDiff(DiffAction action, DiffSubject subject, DiffSeverity severity, DiffLocation[] location = [], 
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