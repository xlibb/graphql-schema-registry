import graphql_schema_registry.parser;

public isolated function getDiff(parser:__Schema newSchema, parser:__Schema oldSchema) returns SchemaDiff[] {

    ComparisionResult typeComparison = getComparision(newSchema.types.keys(), oldSchema.types.keys());
    ComparisionResult dirComparison = getComparision(newSchema.directives.keys(), oldSchema.directives.keys());

    SchemaDiff[] diffs = [];

    SchemaDiff[] schemaTypeDiffs = getSchemaDiffs(TYPE, typeComparison.added, typeComparison.removed);
    appendDiffs(diffs, schemaTypeDiffs);
    SchemaDiff[] schemaDirDiffs = getSchemaDiffs(DIRECTIVE, dirComparison.added, dirComparison.removed);
    appendDiffs(diffs, schemaDirDiffs);

    return diffs;
}

isolated function getSchemaDiffs(DiffSubject subject, string[] added, string[] removed) returns SchemaDiff[] {
    SchemaDiff[] typeDiffs = [];
    foreach string 'type in added {
        typeDiffs.push(createDiff(ADDED, subject, SAFE, value = 'type));
    }
    foreach string 'type in removed {
        typeDiffs.push(createDiff(REMOVED, subject, BREAKING, value = 'type));
    }
    return typeDiffs;
}

isolated function getComparision(string[] newList, string[] oldList) returns ComparisionResult {
    ComparisionResult result = {
        added: [],
        removed: [],
        common: []
    };
    foreach string value in newList {
        if listContains(value, oldList) {
            result.common.push(value);
        } else {
            result.added.push(value);
        }
    }
    foreach string value in oldList {
        if !listContains(value, newList) {
            result.removed.push(value);
        }
    }
    return result;
}