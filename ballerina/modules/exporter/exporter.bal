import graphql_schema_registry.parser;

public class Exporter {

    private parser:__Schema schema;

    public function init(parser:__Schema schema) {
        self.schema = schema;
    }
    
    public function export() returns string|ExportError {
        string[] sections = [];
        if self.schema.appliedDirectives.length() > 0 {
            sections.push(check self.exportSchemaType());
        }
        sections.push(check self.exportDirectives());
        sections.push(check self.exportTypes());
        return string:'join(DOUBLE_LINE_BREAK, ...sections);
    }

    function exportSchemaType() returns string|ExportError {
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives(self.schema.appliedDirectives);

        map<parser:__Field> fieldMap = {
            [QUERY_FIELD]: {args: {}, name: QUERY_FIELD, 'type: self.schema.queryType}
        };
        parser:__Type? mutationType = self.schema.mutationType;
        if mutationType !is () {
            fieldMap[MUTATION_FIELD] = {args: {}, name: MUTATION_FIELD, 'type: mutationType};
        }
        parser:__Type? subscriptionType = self.schema.subscriptionType;
        if subscriptionType !is () {
            fieldMap[SUBSCRIPTION_FIELD] = {args: {}, name: SUBSCRIPTION_FIELD, 'type: subscriptionType};
        }
        string fieldMapSdl = self.addBraces(self.addAsBlock(check self.exportFieldMap(fieldMap, 1)));

        return SCHEMA_TYPE + appliedDirectivesSdl + fieldMapSdl;
    }

    function getKeyValuePair(string key, string value) returns string {
        return key + COLON + SPACE + value;
    }

    function exportTypes() returns string|ExportError {
        string[] typeSdls = [];
        string[] sortedTypeNames = self.schema.types.keys().sort(key = string:toLowerAscii);
        foreach string typeName in sortedTypeNames {
            parser:__Type 'type = self.schema.types.get(typeName);
            if parser:isBuiltInType(typeName) {
                continue;
            }

            match 'type.kind {
                parser:OBJECT => { typeSdls.push(check self.exportObjectType('type)); }
                parser:INTERFACE => { typeSdls.push(check self.exportInterfaceType('type)); }
                parser:INPUT_OBJECT => { typeSdls.push(check self.exportInputObjectType('type)); }
                parser:ENUM => { typeSdls.push(check self.exportEnumType('type)); }
                parser:SCALAR => { typeSdls.push(check self.exportScalarType('type)); }
                parser:UNION => { typeSdls.push(check self.exportUnionType('type)); }
            }
        }

        return string:'join(DOUBLE_LINE_BREAK, ...typeSdls);
    }

    function exportUnionType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        parser:__Type[]? possibleTypes = 'type.possibleTypes;
        if possibleTypes is () {
            return error ExportError("Possible types cannot be empty");
        }

        string descriptionSdl = self.exportDescription('type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives);
        string possibleTypesSdl = check self.exportPossibleTypes(possibleTypes);

        return descriptionSdl + UNION_TYPE + SPACE + typeName + appliedDirectivesSdl + SPACE + EQUAL + SPACE + possibleTypesSdl;
    }

    function exportPossibleTypes(parser:__Type[] possibleTypes) returns string|ExportError {
        string[] typeReferenceSdls = [];
        foreach parser:__Type 'type in possibleTypes {
            typeReferenceSdls.push(check self.exportTypeReference('type));
        }
        return string:'join(SPACE + PIPE + SPACE, ...typeReferenceSdls);
    }

    function exportInterfaceType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        map<parser:__Field>? fields = 'type.fields;
        if fields is () {
            return error ExportError("Interface field map cannot be null");
        }
        parser:__Type[] interfaces = 'type.interfaces ?: [];

        string descriptionSdl = self.exportDescription('type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives);
        string implementsSdl = check self.exportImplements(interfaces);
        string fieldMapSdl = self.addBraces(self.addAsBlock(check self.exportFieldMap(fields, 1)));

        return descriptionSdl + INTERFACE_TYPE + SPACE + typeName + implementsSdl + appliedDirectivesSdl + fieldMapSdl;
    }

    function exportInputObjectType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        string descriptionSdl = self.exportDescription('type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives);

        map<parser:__InputValue>? inputFields = 'type.inputFields;
        if inputFields is () {
            return error ExportError("Input fields cannot be empty");
        }
        string inputFieldSdls = self.addAsBlock(check self.exportInputValues(inputFields, LINE_BREAK, 1));
        inputFieldSdls = self.addBraces(inputFieldSdls);

        return descriptionSdl + INPUT_TYPE + SPACE + typeName + appliedDirectivesSdl + inputFieldSdls;
    }

    function exportScalarType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        string descriptionSdl = self.exportDescription('type.description === "" ? () : 'type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives, EMPTY_STRING, false);

        return descriptionSdl + SCALAR_TYPE + SPACE + typeName + appliedDirectivesSdl;
    }

    function exportEnumType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        parser:__EnumValue[]? enumValues = 'type.enumValues;
        if enumValues is () {
            return error ExportError("Enum values cannot be empty");
        }

        string descriptionSdl = self.exportDescription('type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives);
        string enumValuesSdl = self.addBraces(self.addAsBlock(check self.exportEnumValues(enumValues, 1)));

        return descriptionSdl + ENUM_TYPE + SPACE + typeName + appliedDirectivesSdl + enumValuesSdl;
    }

    function exportEnumValues(parser:__EnumValue[] enumValues, int indentation) returns string|ExportError {
        string[] enumValueSdls = [];
        boolean isFirstInBlock = true;
        foreach parser:__EnumValue value in enumValues {
            enumValueSdls.push(check self.exportEnumValue(value, isFirstInBlock, indentation));
            isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
        }
        return string:'join(LINE_BREAK, ...enumValueSdls);
    }

    function exportEnumValue(parser:__EnumValue value, boolean isFirstInBlock, int indentation) returns string|ExportError {
        string valueNameSdl = value.name;
        string descriptionSdl = self.exportDescription(value.description, indentation, isFirstInBlock);
        string appliedDirsSdl = check self.exportAppliedDirectives(value.appliedDirectives, true);

        return descriptionSdl + self.addIndentation(indentation) + valueNameSdl + appliedDirsSdl;
    }

    function exportObjectType(parser:__Type 'type) returns string|ExportError {
        string typeName = check self.exportTypeName('type);
        map<parser:__Field>? fields = 'type.fields;
        if fields is () {
            return error ExportError("Object field map cannot be null");
        }
        parser:__Type[] interfaces = 'type.interfaces ?: [];

        string descriptionSdl = self.exportDescription('type.description, 0);
        string appliedDirectivesSdl = check self.exportTypeAppliedDirectives('type.appliedDirectives);
        string implementsSdl = check self.exportImplements(interfaces);
        string fieldMapSdl = self.addBraces(self.addAsBlock(check self.exportFieldMap(fields, 1)));

        return descriptionSdl + OBJECT_TYPE + SPACE + typeName + implementsSdl + appliedDirectivesSdl + fieldMapSdl;
    }

    function exportImplements(parser:__Type[] interfaces) returns string|ExportError {
        string implementsSdl = EMPTY_STRING;
        if interfaces.length() > 0 {
            string[] interfaceSdls = [];
            foreach parser:__Type 'type in interfaces {
                interfaceSdls.push(check self.exportTypeReference('type));
            }
            implementsSdl = SPACE + IMPLEMENTS + SPACE + string:'join(SPACE + AMPERSAND + SPACE, ...interfaceSdls);
        }
        return implementsSdl;
    }

    function exportTypeAppliedDirectives(parser:__AppliedDirective[] dirs, string altPrefix = SPACE, boolean addEndingBreak = true) returns string|ExportError {
        return dirs.length() > 0 ? 
                        self.addAsBlock(check self.exportAppliedDirectives(dirs, false, 1), addEndingBreak) 
                        : altPrefix;
    }

    function exportTypeName(parser:__Type 'type) returns string|ExportError {
        string? typeName = 'type.name;
        if typeName is () {
            return error ExportError("Type name cannot be null");
        }
        return typeName;
    }

    function exportFieldMap(map<parser:__Field> fieldMap, int indentation) returns string|ExportError {
        string[] fields = [];
        boolean isFirstInBlock = true;
        foreach parser:__Field 'field in fieldMap {
            fields.push(check self.exportField('field, isFirstInBlock, indentation));
            isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
        }

        return string:'join(LINE_BREAK, ...fields);
    }

    function exportField(parser:__Field 'field, boolean isFirstInBlock, int indentation) returns string|ExportError {
        string typeReferenceSdl = check self.exportTypeReference('field.'type);
        string descriptionSdl = self.exportDescription('field.description, indentation, isFirstInBlock);
        string argsSdl = check self.exportFieldInputValues('field.args, indentation);
        string appliedDirectiveSdl = check self.exportAppliedDirectives('field.appliedDirectives, true);

        string fieldSdl = self.getKeyValuePair('field.name + argsSdl, typeReferenceSdl) + appliedDirectiveSdl;
        return descriptionSdl + self.addIndentation(indentation) + fieldSdl;
    }

    function exportFieldInputValues(map<parser:__InputValue> args, int indentation) returns string|ExportError {
        string argsSdl = EMPTY_STRING;
        if args != {} {
            if args.toArray().some(i => i.description is string) {
                argsSdl = check self.exportInputValues(args, LINE_BREAK, indentation + 1);
                argsSdl = self.addAsBlock(argsSdl) + self.addIndentation(indentation);
            } else {
                argsSdl = check self.exportInputValues(args, COMMA + SPACE);
            }
            argsSdl = self.addParantheses(argsSdl);
        }
        return argsSdl;
    }

    function exportDirectives() returns string|ExportError {
        string[] directives = [];
        foreach parser:__Directive directive in self.schema.directives {
            if parser:isBuiltInDirective(directive.name) {
                continue;
            }
            directives.push(check self.exportDirective(directive));
        }
        directives = directives.sort();
        return string:'join(DOUBLE_LINE_BREAK, ...directives);
    }

    function exportDirective(parser:__Directive directive) returns string|ExportError {
        string directiveDefinitionSdl = string `directive @${directive.name}`;
        string directiveArgsSdl = directive.args.length() > 0 ? 
                                        self.addParantheses(check self.exportInputValues(directive.args, COMMA + SPACE))
                                        : EMPTY_STRING;
        string repeatableSdl = directive.isRepeatable ? REPEATABLE + SPACE : EMPTY_STRING;
        string directiveLocations = ON + SPACE + string:'join(SPACE + PIPE + SPACE, ...directive.locations);

        return directiveDefinitionSdl + directiveArgsSdl + SPACE + repeatableSdl + directiveLocations;
    }

    function exportInputValues(map<parser:__InputValue> args, string seperator, int indentation = 0) returns string|ExportError {
        string[] argSdls = [];
        
        boolean isFirstInBlock = args.toArray().some(i => i.description is string);
        foreach parser:__InputValue arg in args {
            argSdls.push(check self.exportInputValue(arg, isFirstInBlock, indentation));
            isFirstInBlock = isFirstInBlock ? false : isFirstInBlock;
        }
        return string:'join(seperator, ...argSdls);
    }

    function exportInputValue(parser:__InputValue arg, boolean isFirstInBlock, int indentation = 0) returns string|ExportError {
        string typeReferenceSdl = check self.exportTypeReference(arg.'type);
        string descriptionSdl = self.exportDescription(arg.description, indentation, isFirstInBlock);
        string defaultValueSdl = check self.exportDefaultValue(arg.defaultValue);

        string inputValueSdl = self.getKeyValuePair(arg.name, typeReferenceSdl) + defaultValueSdl;
        return descriptionSdl + self.addIndentation(indentation) + inputValueSdl;
    }

    function exportDefaultValue(anydata? defaultValue) returns string|ExportError {
        if defaultValue is () {
            return EMPTY_STRING;
        } else {
            return SPACE + EQUAL + SPACE + check self.exportValue(defaultValue);
        }
    }

    function exportValue(anydata input) returns string|ExportError {
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

    function exportAppliedDirectives(parser:__AppliedDirective[] directives, boolean inline = false, int indentation = 0) returns string|ExportError {
        string appliedDirectiveSdls = EMPTY_STRING;
        if directives.length() > 0 {
            string[] directiveSdls = [];
            foreach parser:__AppliedDirective appliedDirective in directives {
                directiveSdls.push(check self.exportAppliedDirective(appliedDirective, indentation));
            }
            string seperator = inline ? SPACE : LINE_BREAK;
            string prefix = inline ? SPACE : EMPTY_STRING;
            appliedDirectiveSdls = prefix + string:'join(seperator, ...directiveSdls);
        }
        return appliedDirectiveSdls;
    }

    function exportAppliedDirective(parser:__AppliedDirective appliedDirective, int indentation) returns string|ExportError {
        string directiveSdl = string `@${appliedDirective.definition.name}`;
        string[] inputs = [];
        foreach [string, parser:__AppliedDirectiveInputValue] [argName, arg] in appliedDirective.args.entries() {
            if appliedDirective.definition.args.get(argName).defaultValue !== arg.value {
                inputs.push(self.getKeyValuePair(argName, check self.exportValue(arg.value)));
            }
        }
        string inputsSdl = EMPTY_STRING;
        if inputs.length() > 0 {
            inputsSdl = string:'join(COMMA + SPACE, ...inputs);
            inputsSdl = self.addParantheses(inputsSdl);
        }

        return self.addIndentation(indentation) + directiveSdl + inputsSdl;
    }

    function exportDescription(string? description, int indentation, boolean isFirstInBlock = true) returns string {
        string descriptionSdl = EMPTY_STRING;
        if description is string {
            descriptionSdl += isFirstInBlock ? EMPTY_STRING : LINE_BREAK;
            descriptionSdl += self.addIndentation(indentation);
            string newDescription = description.length() <= DESCRIPTION_LINE_LIMIT ? 
                                                description : self.addAsBlock(
                                                                    self.addIndentation(indentation) + description
                                                              ) + self.addIndentation(indentation);
            descriptionSdl += string `"""${newDescription}"""` + LINE_BREAK;
        }
        return descriptionSdl;
    }

    function exportTypeReference(parser:__Type 'type) returns string|ExportError {
        string? typeName = 'type.name;
        if 'type.kind == parser:LIST {
            return self.addSquareBrackets(check self.exportTypeReference(<parser:__Type>'type.ofType));
        } else if 'type.kind == parser:NON_NULL {
            return check self.exportTypeReference(<parser:__Type>'type.ofType) + EXCLAMATION;
        } else if typeName is string {
            return typeName;
        } else {
            return error ExportError("Invalid type reference");
        }
    }

    function addAsBlock(string input, boolean addEndingBreak = true) returns string {
        return LINE_BREAK + input + (addEndingBreak ? LINE_BREAK : EMPTY_STRING);
    }

    function addBraces(string input) returns string {
        return string `{${input}}`;
    }

    function addParantheses(string input) returns string {
        return string `(${input})`;
    }

    function addSquareBrackets(string input) returns string {
        return string `[${input}]`;
    }

    function addIndentation(int level) returns string {
        string indentation = EMPTY_STRING;
        foreach int i in 0...level-1 {
            indentation += INDENTATION;
        }
        return indentation;
    }

}