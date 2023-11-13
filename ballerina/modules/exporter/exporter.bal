import graphql_schema_registry.parser;

class Exporter {

    private parser:__Schema schema;

    function init(parser:__Schema schema) {
        self.schema = schema;
    }
    
    function export() returns string|ExportError {
        string directives = check self.exportDirectives();
        string types = check self.exportTypes();
        return directives;
    }

    function exportTypes() returns string {
        string[] sortedTypeNames = self.schema.types.keys().sort();
        foreach string typeName in sortedTypeNames {
            parser:__Type 'type = self.schema.types.get(typeName);

        }

        return "";
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
        return string:'join(LINE_BREAK + LINE_BREAK, ...directives);
    }

    function exportDirective(parser:__Directive directive) returns string|ExportError {
        string directiveDefinitionSdl = string `directive @${directive.name}`;
        string directiveArgsSdl = self.addParantheses(check self.exportInputValues(directive.args, COMMA + SPACE));
        string repeatableSdl = directive.isRepeatable ? REPEATABLE + SPACE : EMPTY_STRING;
        string directiveLocations = ON + SPACE + string:'join(SPACE + PIPE + SPACE, ...directive.locations);

        return directiveDefinitionSdl + directiveArgsSdl + SPACE + repeatableSdl + directiveLocations;
    }

    function exportInputValues(map<parser:__InputValue> args, string seperator, int indentation = 0) returns string|ExportError {
        string[] argSdls = [];
        foreach parser:__InputValue arg in args {
            argSdls.push(check self.exportInputValue(arg, indentation));
        }
        return string:'join(seperator, ...argSdls);
    }

    function exportInputValue(parser:__InputValue arg, int indentation = 0) returns string|ExportError {
        string typeReferenceSdl = check self.exportTypeReference(arg.'type);
        string descriptionSdl = self.exportDescription(arg.description, indentation);
        string defaultValueSdl = self.exportDefaultValue(arg.defaultValue);
        return self.addIndentation(indentation) + descriptionSdl + arg.name + COLON + SPACE + typeReferenceSdl + defaultValueSdl;
    }

    function exportDefaultValue(anydata? defaultValue) returns string {
        if defaultValue is () {
            return "";
        } else {
            return SPACE + EQUAL + SPACE + self.exportValue(defaultValue);
        }
    }

    function exportValue(anydata input) returns string {
        if input is string {
            return string `"${input}"`;
        } else if input is int|float|boolean {
            return input.toBalString();
        } else if input is parser:__EnumValue {
            return input.name;
        } else {
            return "<UNKNOWN_TYPE>";
        }
    }

    function exportDescription(string? description, int indentation = 0) returns string {
        if description is () {
            return "";
        } else {
            return LINE_BREAK + self.addIndentation(indentation) + string `"""${description}"""` + LINE_BREAK;
        }
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

    function addParantheses(string input) returns string {
        return string `(${input})`;
    }

    function addSquareBrackets(string input) returns string {
        return string `[${input}]`;
    }

    function addIndentation(int level) returns string {
        string indentation = "";
        foreach int i in 0...level-1 {
            indentation += INDENTATION;
        }
        return indentation;
    }

}