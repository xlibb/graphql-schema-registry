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

        SchemaDiff[] typeDefinitionDiffs = getTypeDefinitionDiff(newType, oldType);
        appendDiffs(typeDiffs, typeDefinitionDiffs);

        if !typeDefinitionDiffs.some(t => t.subject === TYPE_KIND && t.action === CHANGED)  {
            match newType.kind {
                parser:OBJECT => {

                }
            }
        }
    }
    return typeDiffs;
}

isolated function getObjectTypeDiff(parser:__Type newObjectType, parser:__Type oldObjectType) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];
    map<parser:__Field>? newFieldMap = newObjectType.fields;
    map<parser:__Field>? oldFieldMap = oldObjectType.fields;

    if newFieldMap !is map<parser:__Field> || oldFieldMap !is map<parser:__Field> {

    } else {
        return error Error("Object type field map cannot be empty");
    }

    return diffs;
}

isolated function getFieldMapDiff(map<parser:__Field> newFieldMap, map<parser:__Field> oldFieldMap) returns SchemaDiff[] {
    SchemaDiff[] diffs = [];

    ComparisionResult fieldComparison = getComparision(newFieldMap.keys(), oldFieldMap.keys());

    SchemaDiff[] fieldDiffs = getSchemaDiffs(FIELD, fieldComparison.added, fieldComparison.removed);
    appendDiffs(diffs, fieldDiffs);

    foreach string fieldName in fieldComparison.common {

    }

    return diffs;
}

isolated function getFieldDiff(parser:__Field newField, parser:__Field oldField) returns SchemaDiff[] {
    SchemaDiff[] diffs = [];
    
    return diffs;
}

isolated function getTypeDefinitionDiff(parser:__Type newType, parser:__Type oldType) returns SchemaDiff[] {
    SchemaDiff[] typeDiffs = [];
    if newType.kind !== oldType.kind {
        typeDiffs.push(createDiff(CHANGED, TYPE_KIND, BREAKING, fromValue = oldType.kind, toValue = newType.kind));
    }

    SchemaDiff? descriptionDiff = getDescriptionDiff(TYPE_DESCRIPTION, newType.description, oldType.description);
    if descriptionDiff is SchemaDiff {
        typeDiffs.push(descriptionDiff);
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

isolated function getDescriptionDiff(DiffSubject subject, string? newDescription, string? oldDescription) returns SchemaDiff? {
    if newDescription is string && oldDescription is () {
        return createDiff(ADDED, subject, SAFE, value = newDescription);
    } else if newDescription is () && oldDescription is string {
        return createDiff(REMOVED, subject, SAFE, value = oldDescription);
    } else if newDescription is string && oldDescription is string && newDescription !== oldDescription {
        return createDiff(CHANGED, subject, SAFE, fromValue = oldDescription, toValue = newDescription);
    } else {
        return ();
    }
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