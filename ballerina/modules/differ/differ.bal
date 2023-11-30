import graphql_schema_registry.parser;

public isolated function getDiff(parser:__Schema newSchema, parser:__Schema oldSchema) returns SchemaDiff[]|Error {

    ComparisionResult typeComparison = getComparision(newSchema.types.keys(), oldSchema.types.keys());
    ComparisionResult dirComparison = getComparision(newSchema.directives.keys(), oldSchema.directives.keys());

    SchemaDiff[] diffs = [];

    SchemaDiff[] schemaTypeDiffs = getMapDiffs(TYPE, typeComparison.added, typeComparison.removed);
    appendDiffs(diffs, schemaTypeDiffs);
    SchemaDiff[] schemaDirDiffs = getMapDiffs(DIRECTIVE, dirComparison.added, dirComparison.removed);
    appendDiffs(diffs, schemaDirDiffs);

    SchemaDiff[] typeDiffs = check getTypesDiff(typeComparison.common, newSchema.types, oldSchema.types);
    appendDiffs(diffs, typeDiffs);

    return diffs;
}

isolated function getTypesDiff(string[] commonTypes, map<parser:__Type> newTypeMap, map<parser:__Type> oldTypeMap) returns SchemaDiff[]|Error {
    SchemaDiff[] typeDiffs = [];
    foreach string typeName in commonTypes {
        parser:__Type newType = newTypeMap.get(typeName);
        parser:__Type oldType = oldTypeMap.get(typeName);

        SchemaDiff[] typeDefinitionDiffs = getTypeDefinitionDiff(newType, oldType);
        appendDiffs(typeDiffs, typeDefinitionDiffs);

        if !typeDefinitionDiffs.some(t => t.subject === TYPE_KIND && t.action === CHANGED)  {
            match newType.kind {
                parser:OBJECT => {
                    appendDiffs(typeDiffs, check getObjectTypeDiff(newType, oldType), location = typeName);
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

    if newFieldMap is map<parser:__Field> && oldFieldMap is map<parser:__Field> {
        appendDiffs(diffs, check getFieldMapDiff(newFieldMap, oldFieldMap));
    } else {
        return error Error("Object type field map cannot be empty");
    }

    return diffs;
}

isolated function getFieldMapDiff(map<parser:__Field> newFieldMap, map<parser:__Field> oldFieldMap) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    ComparisionResult fieldComparison = getComparision(newFieldMap.keys(), oldFieldMap.keys());
    appendDiffs(diffs, getMapDiffs(FIELD, fieldComparison.added, fieldComparison.removed));

    foreach string fieldName in fieldComparison.common {
        appendDiffs(diffs, check getFieldDiff(newFieldMap.get(fieldName), oldFieldMap.get(fieldName)), fieldName);
    }

    return diffs;
}

isolated function getFieldDiff(parser:__Field newField, parser:__Field oldField) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];
    
    SchemaDiff? descriptionDiff = getDescriptionDiff(FIELD_DESCRIPTION, newField.description, oldField.description);
    if descriptionDiff is SchemaDiff {
        appendDiffs(diffs, [descriptionDiff]);
    }

    SchemaDiff? inputTypeDiff = check getTypeReferenceDiff(FIELD_TYPE, newField.'type, oldField.'type);
    if inputTypeDiff is SchemaDiff {
        appendDiffs(diffs, [inputTypeDiff]);
    }

    SchemaDiff? deprecationDiff = getDeprecationDiff(FIELD_DEPRECATION, [newField.isDeprecated, newField.deprecationReason], [oldField.isDeprecated, oldField.deprecationReason]);
    if deprecationDiff is SchemaDiff {
        appendDiffs(diffs, [deprecationDiff]);
    }

    appendDiffs(diffs, check getInputValueMapDiff(ARGUMENT_TYPE, newField.args, oldField.args));

    return diffs;
}

isolated function getDeprecationDiff(ENUM_DEPRECATION | FIELD_DEPRECATION subject, [boolean, string?] newDeprecation, [boolean, string?] oldDeprecation) returns SchemaDiff? {
    if newDeprecation[0] && oldDeprecation[0] {
        if newDeprecation[1] !is () && oldDeprecation[1] !is () && newDeprecation[1] !== oldDeprecation[1] {
            return createDiff(CHANGED, subject, SAFE, fromValue = oldDeprecation[1], toValue = newDeprecation[1]);
        } else if newDeprecation[1] is () && oldDeprecation[1] !is () {
            return createDiff(CHANGED, subject, SAFE, fromValue = oldDeprecation[1], toValue = ());
        } else if newDeprecation[1] !is () && oldDeprecation[1] is () {
            return createDiff(CHANGED, subject, SAFE, fromValue = (), toValue = newDeprecation[1]);
        }
    } else if newDeprecation[0] && !oldDeprecation[0] {
        return createDiff(ADDED, subject, SAFE);
    } else if !newDeprecation[0] && oldDeprecation[0] {
        return createDiff(REMOVED, subject, DANGEROUS);
    }
    return ();
}

isolated function getInputValueMapDiff(INPUT_FIELD_TYPE | ARGUMENT_TYPE subject, map<parser:__InputValue> newArgs, map<parser:__InputValue> oldArgs) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    ComparisionResult argsComparison = getComparision(newArgs.keys(), oldArgs.keys());
    appendDiffs(diffs, getMapDiffs(subject, argsComparison.added, argsComparison.removed));

    foreach string argName in argsComparison.common {
        appendDiffs(diffs, check getInputValueDiff(subject, newArgs.get(argName), oldArgs.get(argName)), argName);
    }

    return diffs;
}

isolated function getInputValueDiff(INPUT_FIELD_TYPE | ARGUMENT_TYPE subject, parser:__InputValue newArg, parser:__InputValue oldArg) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    SchemaDiff? descriptionDiff = getDescriptionDiff(ARGUMENT_DESCRIPTION, newArg.description, oldArg.description);
    if descriptionDiff is SchemaDiff {
        appendDiffs(diffs, [descriptionDiff]);
    }

    SchemaDiff? inputTypeDiff = check getTypeReferenceDiff(subject, newArg.'type, oldArg.'type);
    if inputTypeDiff is SchemaDiff {
        appendDiffs(diffs, [inputTypeDiff]);
    }

    return diffs;
}

// TODO: Check if better algorithm exists
isolated function getTypeReferenceDiff(INPUT_FIELD_TYPE | ARGUMENT_TYPE | FIELD_TYPE subject, parser:__Type newType, parser:__Type oldType) returns SchemaDiff?|Error {
    DiffSeverity? typeChangeSeverity = getTypeRefChangeSeverity(subject === FIELD_TYPE ? "OUTPUT" : "INPUT", newType, oldType);
    if typeChangeSeverity is DiffSeverity {
        string fromValue = check getTypeReferenceAsString(oldType);
        string toValue = check getTypeReferenceAsString(newType);
        return createDiff(CHANGED, subject, typeChangeSeverity, fromValue = fromValue, toValue = toValue);
    }
    return ();
}

isolated function getTypeRefChangeSeverity("INPUT" | "OUTPUT" refType, parser:__Type newType, parser:__Type oldType, DiffSeverity? severity = ()) returns DiffSeverity? {
    parser:__Type? newTypeWrappedType = newType.ofType;
    parser:__Type? oldTypeWrappedType = oldType.ofType;

    if severity is BREAKING {
        return severity;
    } else if newTypeWrappedType is () && oldTypeWrappedType is () {
        return newType.name == oldType.name ? severity : BREAKING;
    } else if newTypeWrappedType !is () && oldTypeWrappedType !is () && newType.kind == oldType.kind {
        return getTypeRefChangeSeverity(refType, newTypeWrappedType, oldTypeWrappedType, severity);
    } else if oldTypeWrappedType !is () && oldType.kind == parser:NON_NULL {
        return getTypeRefChangeSeverity(refType, newType, oldTypeWrappedType, refType === "OUTPUT" ? BREAKING : DANGEROUS);
    } else if newTypeWrappedType !is () && newType.kind == parser:NON_NULL {
        return getTypeRefChangeSeverity(refType, newTypeWrappedType, oldType, refType === "OUTPUT" ? DANGEROUS : BREAKING);
    } 
    return BREAKING;
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

isolated function getMapDiffs(DiffSubject subject, string[] added, string[] removed) returns SchemaDiff[] {
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