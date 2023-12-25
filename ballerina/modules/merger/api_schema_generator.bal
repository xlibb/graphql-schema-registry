import graphql_schema_registry.parser;

public isolated function getApiSchema(parser:__Schema supergraph) returns parser:__Schema {
    parser:__Schema apiSchema = supergraph.clone();
    apiSchema.appliedDirectives = removeFederationAppliedDirectives(apiSchema.appliedDirectives);
    foreach string name in apiSchema.directives.keys() {
        if isSupergraphFederationDirective(name) {
            _ = apiSchema.directives.remove(name);
        }
    }
    foreach [string, parser:__Type] [name, 'type] in apiSchema.types.entries() {
        if isSupergraphFederationType(name) || parser:isBuiltInType(name) {
            _ = apiSchema.types.remove(name);
            continue;
        }
        'type.appliedDirectives = removeFederationAppliedDirectives('type.appliedDirectives);
        removeFieldMapFederationAppliedDirectives('type.fields ?: {}); 
        removeArgMapFederationAppliedDirectives('type.inputFields ?: {});
        removeEnumValuesFederationAppliedDirectives('type.enumValues ?: []);
    }
    return apiSchema;
}

isolated function removeEnumValuesFederationAppliedDirectives(parser:__EnumValue[] values) {
    foreach parser:__EnumValue value in values {
        value.appliedDirectives = removeFederationAppliedDirectives(value.appliedDirectives);
    }
}

isolated function removeFieldMapFederationAppliedDirectives(map<parser:__Field> fieldMap) {
    foreach parser:__Field 'field in fieldMap {
        'field.appliedDirectives = removeFederationAppliedDirectives('field.appliedDirectives);
        removeArgMapFederationAppliedDirectives('field.args);
    }
}

isolated function removeArgMapFederationAppliedDirectives(map<parser:__InputValue> argMap) {
    foreach parser:__InputValue arg in argMap {
        arg.appliedDirectives = removeFederationAppliedDirectives(arg.appliedDirectives);
    }
}

isolated function removeFederationAppliedDirectives(parser:__AppliedDirective[] directives) returns parser:__AppliedDirective[] {
    return directives.filter(d => !isSupergraphFederationDirective(d.definition.name));
}