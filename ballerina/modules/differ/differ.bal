import graphql_schema_registry.parser;

public isolated function diff(parser:__Schema newSchema, parser:__Schema? oldSchema) returns SchemaDiff[]|Error {
    return check getDiff(newSchema, oldSchema ?: parser:createSchema());
}

isolated function getDiff(parser:__Schema newSchema, parser:__Schema oldSchema) returns SchemaDiff[]|Error {

    string[] newSchemaTypes = newSchema.types.keys().filter(k => !parser:isBuiltInType(k));
    string[] oldSchemaTypes = oldSchema.types.keys().filter(k => !parser:isBuiltInType(k));
    string[] newSchemaDirs = newSchema.directives.keys().filter(k => !parser:isBuiltInDirective(k));
    string[] oldSchemaDirs = oldSchema.directives.keys().filter(k => !parser:isBuiltInDirective(k));

    ComparisonResult typeComparison = getComparision(newSchemaTypes, oldSchemaTypes);
    ComparisonResult dirComparison = getComparision(newSchemaDirs, oldSchemaDirs);

    SchemaDiff[] diffs = [];

    SchemaDiff[] schemaTypeDiffs = getMapDiffs(TYPE, typeComparison.added, typeComparison.removed);
    appendDiffs(diffs, schemaTypeDiffs);
    SchemaDiff[] schemaDirDiffs = getMapDiffs(DIRECTIVE, dirComparison.added, dirComparison.removed);
    appendDiffs(diffs, schemaDirDiffs);

    SchemaDiff[] typeDiffs = check getTypesDiff(typeComparison.common, newSchema.types, oldSchema.types);
    appendDiffs(diffs, typeDiffs);

    SchemaDiff[] directiveDiffs = check getDirectivesDiff(dirComparison.common, newSchema.directives, oldSchema.directives);
    appendDiffs(diffs, directiveDiffs);

    return diffs;
}

isolated function getDirectivesDiff(string[] commonDirectives, map<parser:__Directive> newDirectiveMap, map<parser:__Directive> oldDirectiveMap) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];
    foreach string directiveName in commonDirectives {
        parser:__Directive newType = newDirectiveMap.get(directiveName);
        parser:__Directive oldType = oldDirectiveMap.get(directiveName);

        SchemaDiff[] directiveDiffs = check getDirectiveDiff(newType, oldType);
        appendDiffs(diffs, directiveDiffs, location = string `@${directiveName}`);
    }
    return diffs;
}

isolated function getDirectiveDiff(parser:__Directive newDirective, parser:__Directive oldDirective) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    SchemaDiff? descriptionDiff = getDescriptionDiff(DIRECTIVE_DESCRIPTION, newDirective.description, oldDirective.description);
    if descriptionDiff is SchemaDiff {
        appendDiffs(diffs, [descriptionDiff]);
    }

    appendDiffs(diffs, check getInputValueMapDiff(ARGUMENT, newDirective.args, oldDirective.args));

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
                parser:OBJECT | parser:INTERFACE => {
                    appendDiffs(typeDiffs, check getObjectAndInterfaceTypeDiff(newType, oldType), location = typeName);
                }
                parser:ENUM => {
                    appendDiffs(typeDiffs, check getEnumTypeDiff(newType, oldType), location = typeName);
                }
                parser:UNION => {
                    appendDiffs(typeDiffs, check getUnionTypeDiff(newType, oldType), location = typeName);
                }
            }
        }
    }
    return typeDiffs;
}

isolated function getUnionTypeDiff(parser:__Type newType, parser:__Type oldType) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    parser:__Type[]? newPossibleValues = newType.possibleTypes;
    parser:__Type[]? oldPossibleValues = oldType.possibleTypes;
    if newPossibleValues !is parser:__Type[] || oldPossibleValues !is parser:__Type[] {
        return error Error("Possible values cannot be null");
    }

    string[] newPossibleTypeNames = newPossibleValues.map(t => check getTypeReferenceAsString(t));
    string[] oldPossibleTypeNames = oldPossibleValues.map(t => check getTypeReferenceAsString(t));
    ComparisonResult typeComparison = getComparision(newPossibleTypeNames, oldPossibleTypeNames);

    foreach string value in typeComparison.added {
        SchemaDiff possibleTypeDiff = createDiff(ADDED, UNION_MEMBER, DANGEROUS, value = value);
        appendDiffs(diffs, [ possibleTypeDiff ]);
    }
    foreach string value in typeComparison.removed {
        SchemaDiff possibleTypeDiff = createDiff(REMOVED, UNION_MEMBER, BREAKING, value = value);
        appendDiffs(diffs, [ possibleTypeDiff ]);
    }

    return diffs;
}

isolated function getEnumTypeDiff(parser:__Type newEnumType, parser:__Type oldEnumType) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    parser:__EnumValue[]? newEnumValues = newEnumType.enumValues;
    parser:__EnumValue[]? oldEnumValues = oldEnumType.enumValues;
    if newEnumValues !is parser:__EnumValue[] || oldEnumValues !is parser:__EnumValue[] {
        return error Error("Enum values cannot be null");
    }

    map<parser:__EnumValue> newEnumValueMap = {};
    map<parser:__EnumValue> oldEnumValueMap = {};
    foreach parser:__EnumValue value in newEnumValues {
        newEnumValueMap[value.name] = value;
    }
    foreach parser:__EnumValue value in oldEnumValues {
        oldEnumValueMap[value.name] = value;
    }
    ComparisonResult enumValuesComparison = getComparision(newEnumValueMap.keys(), oldEnumValueMap.keys());

    foreach string value in enumValuesComparison.added {
        SchemaDiff enumAddDiff = createDiff(ADDED, ENUM, DANGEROUS, value = value);
        appendDiffs(diffs, [ enumAddDiff ]);
    }
    foreach string value in enumValuesComparison.removed {
        SchemaDiff enumRemoveDiff = createDiff(REMOVED, ENUM, BREAKING, value = value);
        appendDiffs(diffs, [ enumRemoveDiff ]);
    }
    foreach string value in enumValuesComparison.common {
        appendDiffs(diffs, getEnumValueDiff(newEnumValueMap.get(value), oldEnumValueMap.get(value)), location = value);
    }

    return diffs;
}

isolated function getEnumValueDiff(parser:__EnumValue newValue, parser:__EnumValue oldValue) returns SchemaDiff[] {
    SchemaDiff[] diffs = [];
    
    SchemaDiff? descriptionDiff = getDescriptionDiff(ENUM_DESCRIPTION, newValue.description, oldValue.description);
    if descriptionDiff is SchemaDiff {
        appendDiffs(diffs, [descriptionDiff]);
    }

    SchemaDiff? deprecationDiff = getDeprecationDiff(ENUM_DEPRECATION, [newValue.isDeprecated, newValue.deprecationReason], [oldValue.isDeprecated, oldValue.deprecationReason]);
    if deprecationDiff is SchemaDiff {
        appendDiffs(diffs, [deprecationDiff]);
    }

    return diffs;
}

isolated function getObjectAndInterfaceTypeDiff(parser:__Type newObjectType, parser:__Type oldObjectType) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    map<parser:__Field>? newFieldMap = newObjectType.fields;
    map<parser:__Field>? oldFieldMap = oldObjectType.fields;
    if newFieldMap !is map<parser:__Field> || oldFieldMap !is map<parser:__Field> {
        return error Error("Field map cannot be empty");
    }
    appendDiffs(diffs, check getFieldMapDiff(newFieldMap, oldFieldMap));

    parser:__Type[]? newInterfaces = newObjectType.interfaces;
    parser:__Type[]? oldInterfaces = oldObjectType.interfaces;
    if newInterfaces !is parser:__Type[] || oldInterfaces !is parser:__Type[] {
        return error Error("Intefaces cannot be null");
    }
    appendDiffs(diffs, check getInterfacesDiff(newInterfaces, oldInterfaces));

    return diffs;
}

isolated function getInterfacesDiff(parser:__Type[] newInterfaces, parser:__Type[] oldInterfaces) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    string[] newInterfaceNames = newInterfaces.map(i => check getTypeReferenceAsString(i));
    string[] oldInterfaceNames = oldInterfaces.map(i => check getTypeReferenceAsString(i));
    ComparisonResult interfacesComparison = getComparision(newInterfaceNames, oldInterfaceNames);
    foreach string interface in interfacesComparison.added {
        SchemaDiff interfaceDiff = createDiff(ADDED, INTERFACE_IMPLEMENTATION, DANGEROUS, value = interface);
        appendDiffs(diffs, [ interfaceDiff ]);
    }
    foreach string interface in interfacesComparison.removed {
        SchemaDiff interfaceDiff = createDiff(REMOVED, INTERFACE_IMPLEMENTATION, BREAKING, value = interface);
        appendDiffs(diffs, [ interfaceDiff ]);
    }

    return diffs;
}

isolated function getFieldMapDiff(map<parser:__Field> newFieldMap, map<parser:__Field> oldFieldMap) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    ComparisonResult fieldComparison = getComparision(newFieldMap.keys(), oldFieldMap.keys());
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

    appendDiffs(diffs, check getInputValueMapDiff(ARGUMENT, newField.args, oldField.args));

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

isolated function getInputValueMapDiff(InputType 'type, map<parser:__InputValue> newArgs, map<parser:__InputValue> oldArgs) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    ComparisonResult argsComparison = getComparision(newArgs.keys(), oldArgs.keys());
    appendDiffs(diffs, getInputMapDiffs('type, newArgs, argsComparison));

    foreach string argName in argsComparison.common {
        appendDiffs(diffs, check getInputValueDiff('type, newArgs.get(argName), oldArgs.get(argName)), argName);
    }

    return diffs;
}

isolated function getInputValueDiff(InputType 'type, parser:__InputValue newArg, parser:__InputValue oldArg) returns SchemaDiff[]|Error {
    SchemaDiff[] diffs = [];

    SchemaDiff? descriptionDiff = getDescriptionDiff('type is INPUT_FIELD ? INPUT_FIELD_DESCRIPTION : ARGUMENT_DESCRIPTION, newArg.description, oldArg.description);
    if descriptionDiff is SchemaDiff {
        appendDiffs(diffs, [descriptionDiff]);
    }

    SchemaDiff? inputTypeDiff = check getTypeReferenceDiff('type is INPUT_FIELD ? INPUT_FIELD_TYPE : ARGUMENT_TYPE, newArg.'type, oldArg.'type);
    if inputTypeDiff is SchemaDiff {
        appendDiffs(diffs, [inputTypeDiff]);
    }

    SchemaDiff? defaultValueDiff = getDefaultValueDiff('type is INPUT_FIELD ? INPUT_FIELD_DEFAULT : ARGUMENT_DEFAULT, newArg.defaultValue, oldArg.defaultValue);
    if defaultValueDiff is SchemaDiff {
        appendDiffs(diffs, [defaultValueDiff]);
    }

    return diffs;
}

isolated function getDefaultValueDiff(INPUT_FIELD_DEFAULT | ARGUMENT_DEFAULT subject, anydata? newValue, anydata? oldValue) returns SchemaDiff? {
    if newValue is () && oldValue !is () {
        return createDiff(REMOVED, subject, DANGEROUS, value = oldValue.toString());
    } else if newValue !is () && oldValue is () {
        return createDiff(ADDED, subject, DANGEROUS, value = newValue.toString());
    } else if newValue !is () && oldValue !is () && newValue != oldValue {
        return createDiff(CHANGED, subject, DANGEROUS, fromValue = oldValue.toString(), toValue = newValue.toString());
    } else {
        return ();
    }
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

isolated function getInputMapDiffs(DiffSubject subject, map<parser:__InputValue> newArgs, ComparisonResult argsComparison) returns SchemaDiff[] {
    SchemaDiff[] typeDiffs = [];
    foreach string 'type in argsComparison.added {
        boolean isNewTypeNonNullable = newArgs.get('type).'type.kind is parser:NON_NULL;
        typeDiffs.push(createDiff(ADDED, subject, isNewTypeNonNullable ? BREAKING : DANGEROUS, value = 'type));
    }
    foreach string 'type in argsComparison.removed {
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

isolated function getComparision(string[] newList, string[] oldList) returns ComparisonResult {
    ComparisonResult result = {
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