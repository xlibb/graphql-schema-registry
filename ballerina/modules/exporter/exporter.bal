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

public isolated function export(parser:__Schema schema) returns string|ExportError {
    string[] sections = [];

    string? schemaSdl = check exportSchemaType(schema);
    if schemaSdl is string {
        sections.push(schemaSdl);
    }
    string? customDirectivesSdl = check exportDirectives(schema);
    if customDirectivesSdl is string {
        sections.push(customDirectivesSdl);
    }
    sections.push(check exportTypes(schema));

    return string:'join(DOUBLE_LINE_BREAK, ...sections);
}

isolated function exportSchemaType(parser:__Schema schema) returns string?|ExportError {
    if schema.appliedDirectives.length() > 0 {
        string appliedDirectivesSdl = check exportTypeAppliedDirectives(schema.appliedDirectives);

        map<parser:__Field> fieldMap = {
            [QUERY_FIELD]: {args: {}, name: QUERY_FIELD, 'type: schema.queryType}
        };
        parser:__Type? mutationType = schema.mutationType;
        if mutationType !is () {
            fieldMap[MUTATION_FIELD] = {args: {}, name: MUTATION_FIELD, 'type: mutationType};
        }
        parser:__Type? subscriptionType = schema.subscriptionType;
        if subscriptionType !is () {
            fieldMap[SUBSCRIPTION_FIELD] = {args: {}, name: SUBSCRIPTION_FIELD, 'type: subscriptionType};
        }
        string fieldMapSdl = addBraces(addAsBlock(check exportFieldMap(fieldMap, 1)));

        return string `${SCHEMA_TYPE}${appliedDirectivesSdl}${fieldMapSdl}`;
    } else {
        return ();
    }
}

isolated function getKeyValuePair(string key, string value) returns string {
    return string `${key}${COLON} ${value}`;
}

isolated function exportTypes(parser:__Schema schema) returns string|ExportError {
    string[] typeSdls = [];
    string[] sortedTypeNames = schema.types.keys().sort(key = string:toLowerAscii);
    foreach string typeName in sortedTypeNames {
        parser:__Type 'type = schema.types.get(typeName);
        if parser:isBuiltInType(typeName) {
            continue;
        }

        match 'type.kind {
            parser:OBJECT => { typeSdls.push(check exportObjectType('type)); }
            parser:INTERFACE => { typeSdls.push(check exportInterfaceType('type)); }
            parser:INPUT_OBJECT => { typeSdls.push(check exportInputObjectType('type)); }
            parser:ENUM => { typeSdls.push(check exportEnumType('type)); }
            parser:SCALAR => { typeSdls.push(check exportScalarType('type)); }
            parser:UNION => { typeSdls.push(check exportUnionType('type)); }
        }
    }

    return string:'join(DOUBLE_LINE_BREAK, ...typeSdls);
}

isolated function exportUnionType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    parser:__Type[]? possibleTypes = 'type.possibleTypes;
    if possibleTypes is () {
        return error ExportError("Possible types cannot be empty");
    }

    string descriptionSdl = exportDescription('type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives, EMPTY_STRING);
    string possibleTypesSdl = check exportPossibleTypes(possibleTypes);

    return string `${descriptionSdl}${UNION_TYPE} ${typeName}${appliedDirectivesSdl} ${EQUAL} ${possibleTypesSdl}`;
}

isolated function exportPossibleTypes(parser:__Type[] possibleTypes) returns string|ExportError {
    string[] typeReferenceSdls = [];
    foreach parser:__Type 'type in possibleTypes {
        typeReferenceSdls.push(check exportTypeReference('type));
    }
    return string:'join(string ` ${PIPE} `, ...typeReferenceSdls);
}

isolated function exportInterfaceType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    map<parser:__Field>? fields = 'type.fields;
    if fields is () {
        return error ExportError("Interface field map cannot be null");
    }
    parser:__Type[] interfaces = 'type.interfaces ?: [];

    string descriptionSdl = exportDescription('type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives);
    string implementsSdl = check exportImplements(interfaces);
    string fieldMapSdl = addBraces(addAsBlock(check exportFieldMap(fields, 1)));

    return string `${descriptionSdl}${INTERFACE_TYPE} ${typeName}${implementsSdl}${appliedDirectivesSdl}${fieldMapSdl}`;
}

isolated function exportInputObjectType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    string descriptionSdl = exportDescription('type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives);

    map<parser:__InputValue>? inputFields = 'type.inputFields;
    if inputFields is () {
        return error ExportError("Input fields cannot be empty");
    }
    string inputFieldSdls = addAsBlock(check exportInputValues(inputFields, LINE_BREAK, 1));
    inputFieldSdls = addBraces(inputFieldSdls);

    return string `${descriptionSdl}${INPUT_TYPE} ${typeName}${appliedDirectivesSdl}${inputFieldSdls}`;
}

isolated function exportScalarType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    string descriptionSdl = exportDescription('type.description === "" ? () : 'type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives, EMPTY_STRING, false);

    return string `${descriptionSdl}${SCALAR_TYPE} ${typeName}${appliedDirectivesSdl}`;
}

isolated function exportEnumType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    parser:__EnumValue[]? enumValues = 'type.enumValues;
    if enumValues is () {
        return error ExportError("Enum values cannot be empty");
    }

    string descriptionSdl = exportDescription('type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives);
    string enumValuesSdl = addBraces(addAsBlock(check exportEnumValues(enumValues, 1)));

    return string `${descriptionSdl}${ENUM_TYPE} ${typeName}${appliedDirectivesSdl}${enumValuesSdl}`;
}

isolated function exportEnumValues(parser:__EnumValue[] enumValues, int indentation) returns string|ExportError {
    string[] enumValueSdls = [];
    boolean isFirstInBlock = true;
    foreach parser:__EnumValue value in enumValues {
        enumValueSdls.push(check exportEnumValue(value, isFirstInBlock, indentation));
        isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
    }
    return string:'join(LINE_BREAK, ...enumValueSdls);
}

isolated function exportEnumValue(parser:__EnumValue value, boolean isFirstInBlock, int indentation) returns string|ExportError {
    string valueNameSdl = value.name;
    string descriptionSdl = exportDescription(value.description, indentation, isFirstInBlock);
    string appliedDirsSdl = check exportAppliedDirectives(value.appliedDirectives, true);

    return string `${descriptionSdl}${addIndentation(indentation)}${valueNameSdl}${appliedDirsSdl}`;
}

isolated function exportObjectType(parser:__Type 'type) returns string|ExportError {
    string typeName = check exportTypeName('type);
    map<parser:__Field>? fields = 'type.fields;
    if fields is () {
        return error ExportError("Object field map cannot be null");
    }
    parser:__Type[] interfaces = 'type.interfaces ?: [];

    string descriptionSdl = exportDescription('type.description, 0);
    string appliedDirectivesSdl = check exportTypeAppliedDirectives('type.appliedDirectives);
    string implementsSdl = check exportImplements(interfaces);
    string fieldMapSdl = addBraces(addAsBlock(check exportFieldMap(fields, 1)));

    return string `${descriptionSdl}${OBJECT_TYPE} ${typeName}${implementsSdl}${appliedDirectivesSdl}${fieldMapSdl}`;
}

isolated function exportImplements(parser:__Type[] interfaces) returns string|ExportError {
    string implementsSdl = EMPTY_STRING;
    if interfaces.length() > 0 {
        string[] interfaceSdls = [];
        foreach parser:__Type 'type in interfaces {
            interfaceSdls.push(check exportTypeReference('type));
        }
        implementsSdl = string ` ${IMPLEMENTS} ` + 
                        string:'join(string ` ${AMPERSAND} `, ...interfaceSdls);
    }
    return implementsSdl;
}

isolated function exportTypeAppliedDirectives(parser:__AppliedDirective[] dirs, string alternative = " ", boolean addEndingBreak = true) returns string|ExportError {
    return dirs.length() > 0 ? 
                    addAsBlock(check exportAppliedDirectives(dirs, false, 1), addEndingBreak) 
                    : alternative;
}

isolated function exportTypeName(parser:__Type 'type) returns string|ExportError {
    string? typeName = 'type.name;
    if typeName is () {
        return error ExportError("Type name cannot be null");
    }
    return typeName;
}

isolated function exportFieldMap(map<parser:__Field> fieldMap, int indentation) returns string|ExportError {
    string[] fields = [];
    boolean isFirstInBlock = true;
    foreach parser:__Field 'field in fieldMap {
        fields.push(check exportField('field, isFirstInBlock, indentation));
        isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
    }

    return string:'join(LINE_BREAK, ...fields);
}

isolated function exportField(parser:__Field 'field, boolean isFirstInBlock, int indentation) returns string|ExportError {
    string typeReferenceSdl = check exportTypeReference('field.'type);
    string descriptionSdl = exportDescription('field.description, indentation, isFirstInBlock);
    string argsSdl = check exportFieldInputValues('field.args, indentation);
    string appliedDirectiveSdl = check exportAppliedDirectives('field.appliedDirectives, true);

    string fieldNameWithArgsSdl = string `${'field.name}${argsSdl}`;
    string fieldSdl = getKeyValuePair(fieldNameWithArgsSdl, typeReferenceSdl);
    string fieldWithAppliedDirectivesSdl = string `${fieldSdl}${appliedDirectiveSdl}`;
    return string `${descriptionSdl}${addIndentation(indentation)}${fieldWithAppliedDirectivesSdl}`;
}

isolated function exportFieldInputValues(map<parser:__InputValue> args, int indentation) returns string|ExportError {
    string argsSdl = EMPTY_STRING;
    if args != {} {
        if args.toArray().some(i => i.description is string) {
            argsSdl = check exportInputValues(args, LINE_BREAK, indentation + 1);
            argsSdl = string `${addAsBlock(argsSdl)}${addIndentation(indentation)}`;
        } else {
            argsSdl = check exportInputValues(args, COMMA_FOLLOWING_SPACE);
        }
        argsSdl = addParantheses(argsSdl);
    }
    return argsSdl;
}

isolated function exportDirectives(parser:__Schema schema) returns string?|ExportError {
    string[] directives = [];
    foreach parser:__Directive directive in schema.directives {
        if parser:isBuiltInDirective(directive.name) {
            continue;
        }
        directives.push(check exportDirective(directive));
    }
    directives = directives.sort();

    return directives.length() > 0 ? string:'join(DOUBLE_LINE_BREAK, ...directives) : ();
}

isolated function exportDirective(parser:__Directive directive) returns string|ExportError {
    string directiveDefinitionSdl = string `directive @${directive.name}`;
    string directiveArgsSdl = directive.args.length() > 0 ? 
                                    addParantheses(check exportInputValues(directive.args, COMMA_FOLLOWING_SPACE))
                                    : EMPTY_STRING;
    string repeatableSdl = directive.isRepeatable ? string `${REPEATABLE} ` : EMPTY_STRING;
    string validLocations = string:'join(string ` ${PIPE} `, ...directive.locations);
    string directiveLocations = string `${ON} ${validLocations}`;

    return string `${directiveDefinitionSdl}${directiveArgsSdl} ${repeatableSdl}${directiveLocations}`;
}

isolated function exportInputValues(map<parser:__InputValue> args, string seperator, int indentation = 0) returns string|ExportError {
    string[] argSdls = [];
    
    boolean isFirstInBlock = args.toArray().some(i => i.description is string);
    foreach parser:__InputValue arg in args {
        argSdls.push(check exportInputValue(arg, isFirstInBlock, indentation));
        isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
    }
    return string:'join(seperator, ...argSdls);
}

isolated function exportInputValue(parser:__InputValue arg, boolean isFirstInBlock, int indentation = 0) returns string|ExportError {
    string typeReferenceSdl = check exportTypeReference(arg.'type);
    string descriptionSdl = exportDescription(arg.description, indentation, isFirstInBlock);
    string defaultValueSdl = check exportDefaultValue(arg.defaultValue);
    string appliedDirectivesSdl = check exportAppliedDirectives(arg.appliedDirectives, true);

    string inputValueWithType = getKeyValuePair(arg.name, typeReferenceSdl);
    string inputValueSdl = string `${inputValueWithType}${defaultValueSdl}${appliedDirectivesSdl}`;
    return string `${descriptionSdl}${addIndentation(indentation)}${inputValueSdl}`;
}

isolated function exportDefaultValue(anydata? defaultValue) returns string|ExportError {
    if defaultValue is () {
        return EMPTY_STRING;
    } else {
        return string ` ${EQUAL} ${check exportValue(defaultValue)}`;
    }
}

isolated function exportValue(anydata input) returns string|ExportError {
    if input is string {
        return string `"${input}"`;
    } else if input is int|float|boolean {
        return input.toBalString();
    } else if input is parser:__EnumValue {
        return input.name;
    } else {
        return error ExportError("Invalid input");
    }
}

isolated function exportAppliedDirectives(parser:__AppliedDirective[] directives, boolean inline = false, int indentation = 0) returns string|ExportError {
    string appliedDirectiveSdls = EMPTY_STRING;
    if directives.length() > 0 {
        string[] directiveSdls = [];
        foreach parser:__AppliedDirective appliedDirective in directives.sort("ascending", k => k.definition.name.toLowerAscii()) {
            directiveSdls.push(check exportAppliedDirective(appliedDirective, indentation));
        }
        string seperator = inline ? " " : LINE_BREAK;
        string prefix = inline ? " " : EMPTY_STRING;
        appliedDirectiveSdls = string `${prefix}${string:'join(seperator, ...directiveSdls)}`;
    }
    return appliedDirectiveSdls;
}

isolated function exportAppliedDirective(parser:__AppliedDirective appliedDirective, int indentation) returns string|ExportError {
    string directiveSdl = string `@${appliedDirective.definition.name}`;
    string[] inputs = [];
    foreach [string, parser:__AppliedDirectiveInputValue] [argName, arg] in appliedDirective.args.entries() {
        if appliedDirective.definition.args.get(argName).defaultValue !== arg.value {
            inputs.push(getKeyValuePair(argName, check exportValue(arg.value)));
        }
    }
    string inputsSdl = EMPTY_STRING;
    if inputs.length() > 0 {
        inputsSdl = string:'join(COMMA_FOLLOWING_SPACE, ...inputs);
        inputsSdl = addParantheses(inputsSdl);
    }

    return string `${addIndentation(indentation)}${directiveSdl}${inputsSdl}`;
}

isolated function exportDescription(string? description, int indentation, boolean isFirstInBlock = true) returns string {
    string descriptionSdl = EMPTY_STRING;
    if description is string {
        descriptionSdl += isFirstInBlock ? EMPTY_STRING : LINE_BREAK;
        descriptionSdl += addIndentation(indentation);
        string blockDescription = addAsBlock(addIndentation(indentation) + description) + addIndentation(indentation);
        string newDescription = description.length() <= DESCRIPTION_LINE_LIMIT ? description : blockDescription;
        descriptionSdl += string `"""${newDescription}"""${LINE_BREAK}`;
    }
    return descriptionSdl;
}

isolated function exportTypeReference(parser:__Type 'type) returns string|ExportError {
    string? typeName = 'type.name;
    if 'type.kind == parser:LIST {
        return addSquareBrackets(check exportTypeReference(<parser:__Type>'type.ofType));
    } else if 'type.kind == parser:NON_NULL {
        return string `${check exportTypeReference(<parser:__Type>'type.ofType)}${EXCLAMATION}`;
    } else if typeName is string {
        return typeName;
    } else {
        return error ExportError("Invalid type reference");
    }
}

isolated function addAsBlock(string input, boolean addEndingBreak = true) returns string {
    return string `${LINE_BREAK}${input}${(addEndingBreak ? LINE_BREAK : EMPTY_STRING)}`;
}

isolated function addBraces(string input) returns string {
    return string `{${input}}`;
}

isolated function addParantheses(string input) returns string {
    return string `(${input})`;
}

isolated function addSquareBrackets(string input) returns string {
    return string `[${input}]`;
}

isolated function addIndentation(int level) returns string {
    string indentation = EMPTY_STRING;
    foreach int i in 0...level-1 {
        indentation += INDENTATION;
    }
    return indentation;
}
