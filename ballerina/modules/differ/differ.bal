import graphql_schema_registry.parser;

public isolated function getDiff(parser:__Schema newSchema, parser:__Schema oldSchema) returns SchemaDiff[] {

    ComparisionResult typeComparison = getComparision(newSchema.types.keys(), oldSchema.types.keys());
    ComparisionResult dirComparison = getComparision(newSchema.directives.keys(), oldSchema.directives.keys());

    SchemaDiff[] diffs = [];

    SchemaDiff[] schemaTypeDiffs = getSchemaDiffs(TYPE, typeComparison.added, typeComparison.removed);
    appendDiffs(diffs, schemaTypeDiffs);
    SchemaDiff[] schemaDirDiffs = getSchemaDiffs(DIRECTIVE, dirComparison.added, dirComparison.removed);
    appendDiffs(diffs, schemaDirDiffs);

    SchemaDiff[] typeDiffs = getTypesDiff(typeComparison.common, newSchema.types, oldSchema.types);
    appendDiffs(diffs, typeDiffs);

    return diffs;
}

isolated function getTypesDiff(string[] commonTypes, map<parser:__Type> newTypeMap, map<parser:__Type> oldTypeMap) returns SchemaDiff[] {
    SchemaDiff[] typeDiffs = [];
    foreach string typeName in commonTypes {
        parser:__Type newType = newTypeMap.get(typeName);
        parser:__Type oldType = oldTypeMap.get(typeName);

        appendDiffs(typeDiffs, getTypeDiff(newType, oldType));
    }
    return typeDiffs;
}

isolated function getTypeDiff(parser:__Type newType, parser:__Type oldType) returns SchemaDiff[] {
    SchemaDiff[] typeDiffs = [];
    if newType.kind !== oldType.kind {
        typeDiffs.push(createDiff(CHANGED, TYPE_KIND, BREAKING, fromValue = oldType.kind, toValue = newType.kind));
    }
    if newType.description !== oldType.description {
        typeDiffs.push(createDiff(CHANGED, TYPE_DESCRIPTION, SAFE, fromValue = oldType.description, toValue = newType.description));
    }
    addDiffsLocation(typeDiffs, newType.name);

    return typeDiffs;
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