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

import ballerina/lang.regexp;
import graphql_schema_registry.parser;

public class Merger {

    private Supergraph supergraph;
    private map<Subgraph> subgraphs;
    private map<parser:__EnumValue> joinGraphMap;

    public isolated function init(Subgraph[] subgraphs) returns error? {
        self.subgraphs = {};
        Subgraph[] sortedSubgraphs = subgraphs.sort("ascending", s => s.name);
        foreach Subgraph subgraph in sortedSubgraphs {
            Subgraph updatedSubgraph = subgraph.clone();
            updatedSubgraph.isFederation2Subgraph = check isFederation2Subgraph(updatedSubgraph);
            self.subgraphs[subgraph.name] = updatedSubgraph;
        }
        self.joinGraphMap = {};
        self.supergraph = {
            schema: parser:createSchema(),
            subgraphs: self.subgraphs.toArray()
        };
    }

    public isolated function merge() returns SupergraphMergeResult|MergeError[]|InternalError|error {
        Hint[] mergeHints = [];

        check self.addFederationDefinitions();
        check self.populateFederationJoinGraphEnum();
        MergeError[]? shallowTypeMergeResult = check self.addTypesShallow();
        if shallowTypeMergeResult is MergeError[] {
            return createMergeErrorMessages(shallowTypeMergeResult);
        }
        check self.addDirectives();

        Hint[] unionMergeHints = check self.mergeUnionTypes();
        appendHints(mergeHints, unionMergeHints);
        check self.mergeImplementsRelationship();

        Hint[]|MergeError[] objectMergeHints = check self.mergeObjectTypes();
        if objectMergeHints is MergeError[] {
            return createMergeErrorMessages(objectMergeHints);
        } else if objectMergeHints is Hint[] {
            appendHints(mergeHints, objectMergeHints);
        }

        Hint[]|MergeError[] interfaceMergeHints = check self.mergeInterfaceTypes();
        if interfaceMergeHints is MergeError[] {
            return createMergeErrorMessages(interfaceMergeHints);
        } else if interfaceMergeHints is Hint[] {
            appendHints(mergeHints, interfaceMergeHints);
        }

        Hint[]|MergeError[] inputTypeMergeHints = check self.mergeInputTypes();
        if inputTypeMergeHints is MergeError[] {
            return createMergeErrorMessages(inputTypeMergeHints);
        } else if inputTypeMergeHints is Hint[] {
            appendHints(mergeHints, inputTypeMergeHints);
        }

        Hint[]|MergeError[] enumTypeMergeHints = check self.mergeEnumTypes();
        if enumTypeMergeHints is MergeError[] {
            return createMergeErrorMessages(enumTypeMergeHints);
        } else if enumTypeMergeHints is Hint[] {
            appendHints(mergeHints, enumTypeMergeHints);
        }

        Hint[] scalarTypeMergeHints = check self.mergeScalarTypes();
        appendHints(mergeHints, scalarTypeMergeHints);

        check self.applyJoinTypeDirectives();
        check self.populateRootTypes();

        mergeHints = self.filterRootTypeHints(mergeHints);

        return {
            result: self.supergraph,
            hints: mergeHints
        };
    }

    public function getSubgraphs() returns map<Subgraph> {
        return self.subgraphs.clone();
    }

    isolated function addFederationDefinitions() returns InternalError? {
        map<parser:__Type> federationTypes = check getFederationTypes(self.supergraph.schema.types);
        foreach parser:__Type 'type in federationTypes {
            check self.addTypeToSupergraph('type);
        }
        map<parser:__Directive> federationDirectives = getFederationDirectives(self.supergraph.schema.types);
        foreach parser:__Directive directive in federationDirectives {
            self.addDirectiveToSupergraph(directive);
        }

        map<parser:__Field>? queryFields = (check self.getTypeFromSupergraph(parser:QUERY_TYPE)).fields;
        if queryFields is () {
            return error InternalError(string `'${parser:QUERY_TYPE}' field map cannot be null`);
        }
        parser:__Type _serviceType = parser:wrapType(check self.getTypeFromSupergraph(parser:_SERVICE_TYPE),
                                                     parser:NON_NULL);

        queryFields[_SERVICE_FIELD_TYPE] = {
            name: _SERVICE_FIELD_TYPE,
            'type: _serviceType,
            args: {}
        };
        
        check self.applyLinkDirective(self.supergraph.schema, LINK_SPEC_URL);
        check self.applyLinkDirective(self.supergraph.schema, JOIN_SPEC_URL, EXECUTION);
    }

    isolated function populateFederationJoinGraphEnum() returns InternalError? {
        parser:__Type joinGraphType = check self.getTypeFromSupergraph(JOIN_GRAPH_TYPE);
        parser:__EnumValue[]? joinGraphEnumValues = joinGraphType.enumValues;
        if joinGraphEnumValues is () {
            return error InternalError(string `'${JOIN_GRAPH_TYPE}' enum values cannot be null`);
        }
        foreach Subgraph subgraph in self.subgraphs {
            parser:__EnumValue enumValue = {
                name: subgraph.name.toUpperAscii()
            };
            check self.applyJoinGraph(enumValue, subgraph.name, subgraph.url);

            joinGraphEnumValues.push(enumValue);
            self.joinGraphMap[subgraph.name] = enumValue;
        }
    }

    isolated function addTypesShallow() returns MergeError[]|InternalError? {
        map<map<TypeKindSourceGroup>> typeNameToMapOfTypeKindMap = self.groupTypeByTypeKind();

        MergeError[] errors = [];
        foreach [string, map<TypeKindSourceGroup>] [typeName, typeKindSourceSubgraphsMap] in typeNameToMapOfTypeKindMap.entries() {
            if typeKindSourceSubgraphsMap.length() != 1 {
                HintDetail[] typeKindMismatchDetails = [];
                foreach [string, TypeKindSourceGroup] [typeKind, sourceSubgraphs] in typeKindSourceSubgraphsMap.entries() {
                    HintDetail mismatchDetail = {
                        value: typeKind,
                        consistentSubgraphs: sourceSubgraphs.subgraphs,
                        inconsistentSubgraphs: []
                    };
                    typeKindMismatchDetails.push(mismatchDetail);
                }

                Hint typeKindMismatch = {
                    code: TYPE_KIND_MISMATCH,
                    location: [typeName],
                    details: typeKindMismatchDetails
                };
                errors.push(error MergeError("Type kind mismatch", hint = typeKindMismatch));
                continue;
            } 

            check self.addTypeToSupergraph({
                name: typeName,
                kind: typeKindSourceSubgraphsMap.toArray()[0].definition
            });
            
        }
        return errors.length() > 0 ? errors : ();
    }

    isolated function groupTypeByTypeKind() returns map<map<TypeKindSourceGroup>> {
        map<map<TypeKindSourceGroup>> typeNameToMapOfTypeKindMap = {};
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Type] [typeName, typeDefinition] in subgraph.schema.types.entries() {
                if parser:isBuiltInType(typeName) || isSubgraphFederationType(typeName) {
                    continue;
                }

                parser:__TypeKind typeKind = typeDefinition.kind;
                if typeNameToMapOfTypeKindMap.hasKey(typeName) {
                    map<TypeKindSourceGroup> typeKindToSourceSubgraphsMap = typeNameToMapOfTypeKindMap.get(typeName);
                    if typeKindToSourceSubgraphsMap.hasKey(typeKind) {
                        typeKindToSourceSubgraphsMap.get(typeKind).subgraphs.push(subgraph.name);
                    } else {
                        typeKindToSourceSubgraphsMap[typeKind] = {
                            definition: typeKind,
                            subgraphs: [subgraph.name]
                        };
                    }
                } else {
                    map<TypeKindSourceGroup> definingSubgraph = {
                        [typeKind] : {
                            definition: typeKind,
                            subgraphs: [subgraph.name]
                        }
                    };
                    typeNameToMapOfTypeKindMap[typeName] = definingSubgraph;
                }
            }
        }
        return typeNameToMapOfTypeKindMap;
    }

    isolated function addDirectives() returns InternalError? {
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Directive] [directiveName, directiveDefinition] in subgraph.schema.directives.entries() {
                if parser:isBuiltInDirective(directiveName) || !parser:isExecutableDirective(directiveDefinition) || 
                   isSubgraphFederationDirective(directiveName) || isSupergraphFederationDirective(directiveName) {
                    continue;
                }

                self.addDirectiveToSupergraph({
                    name: directiveDefinition.name,
                    locations: check getDirectiveLocationsFromStrings(directiveDefinition.locations),
                    args: check self.getInputValueMap(directiveDefinition.args),
                    isRepeatable: directiveDefinition.isRepeatable
                });
            }
        }
    }

    isolated function mergeUnionTypes() returns Hint[]|InternalError {
        map<parser:__Type> supergraphUnionTypes = self.getSupergraphTypesOfKind(parser:UNION);
        Hint[] hints = [];
        foreach [string, parser:__Type] [typeName, supergraphUnionDefinition] in supergraphUnionTypes.entries() {
            Subgraph[] definingSubgraphs = self.getDefiningSubgraphs(typeName);

            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in definingSubgraphs {
                descriptionSources.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, typeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            appendHints(hints, descriptionMergeResult.hints, typeName);
            supergraphUnionDefinition.description = descriptionMergeResult.result;

            PossibleTypesSource[] possibleTypesSources = [];
            foreach Subgraph subgraph in definingSubgraphs {
                parser:__Type[]? possibleTypesResult = getTypeFromSchema(subgraph.schema, typeName).possibleTypes;
                if possibleTypesResult is () {
                    return error InternalError(string `'${typeName}' possible types cannot be null`);
                }
                possibleTypesSources.push({
                    subgraph: subgraph.name,
                    definition: possibleTypesResult
                });
            }
            PossibleTypesMergeResult possibleTypesMergeResult = check self.mergePossibleTypes(possibleTypesSources);
            supergraphUnionDefinition.possibleTypes = possibleTypesMergeResult.result;
            appendHints(hints, possibleTypesMergeResult.hints, typeName);

            foreach TypeReferenceSourceGroup sourceGroup in possibleTypesMergeResult.sources {
                foreach string consistentSubgraph in sourceGroup.subgraphs {
                    check self.applyJoinUnionMember(
                        supergraphUnionDefinition,
                        consistentSubgraph,
                        sourceGroup.definition
                    );
                }                
            }
        }
        return hints;
    }

    isolated function mergeImplementsRelationship() returns InternalError? {
        check self.mergeImplementsOfKind(parser:OBJECT);
        check self.mergeImplementsOfKind(parser:INTERFACE);
    }

    isolated function mergeImplementsOfKind(parser:OBJECT|parser:INTERFACE kind) returns InternalError? {
        map<parser:__Type> supergraphTypes = self.getSupergraphTypesOfKind(kind);
        foreach [string, parser:__Type] [typeName, supergraphTypeDefinition] in supergraphTypes.entries() {
            Subgraph[] definingSubgraphs = self.getDefiningSubgraphs(typeName);

            check self.mergeInterfaceImplements(supergraphTypeDefinition, definingSubgraphs);
        }
    }

    isolated function mergeInterfaceImplements(parser:__Type supergraphTypeDefinition, Subgraph[] definingSubgraphs) returns InternalError? {
        string? supergraphTypeName = supergraphTypeDefinition.name;
        if supergraphTypeName is () {
            return error InternalError("Supergraph type definition name cannot be null");
        }
        supergraphTypeDefinition.interfaces = [];

        foreach Subgraph subgraph in definingSubgraphs {
            parser:__Type[]? interfacesFromSubgraph = getTypeFromSchema(subgraph.schema, supergraphTypeName).interfaces;
            if interfacesFromSubgraph is () {
                return error InternalError(string `'${supergraphTypeName}' interfaces cannot be null on Subgraph '${subgraph.name}'.`);
            }

            foreach parser:__Type subgraphInterface in interfacesFromSubgraph {
                parser:__Type supergraphInterface = check self.getTypeFromSupergraph(subgraphInterface.name);

                check implementInterfaceToType(supergraphTypeDefinition, supergraphInterface);
                check self.applyJoinImplementsDirective(supergraphTypeDefinition, subgraph, supergraphInterface);
            }
        }
    }

    isolated function mergeObjectTypes() returns Hint[]|MergeError[]|error {
        map<parser:__Type> supergraphObjectTypes = self.getSupergraphTypesOfKind(parser:OBJECT);
        Hint[] hints = [];
        MergeError[] errors = [];
        foreach [string, parser:__Type] [typeName, supergraphObjectDefinition] in supergraphObjectTypes.entries() {
            if parser:isBuiltInType(typeName) || isSupergraphFederationType(typeName) {
                continue;
            }

            Subgraph[] definingSubgraphs = self.getDefiningSubgraphs(typeName);

            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in definingSubgraphs {
                descriptionSources.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, typeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            appendHints(hints, descriptionMergeResult.hints, typeName);
            supergraphObjectDefinition.description = descriptionMergeResult.result;

            FieldMapSource[] fieldMapSources = [];
            foreach Subgraph subgraph in definingSubgraphs {
                parser:__Type subgraphType = getTypeFromSchema(subgraph.schema, typeName);
                EntityStatus entityStatus = check self.isEntity(subgraphType);
                map<parser:__Field>? subgraphFields = subgraphType.fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMapSources.push({
                        subgraph: subgraph.name, 
                        definition: check self.getFilteredFields(typeName, subgraphFields),
                        isDefiningTypeShareable: !subgraph.isFederation2Subgraph || self.isTypeAllowsMergingFields(subgraphType),
                        entityStatus: entityStatus
                    });
                }
            }
            FieldMapMergeResult|MergeError[] mergedFields = check self.mergeFields(fieldMapSources);
            if mergedFields is MergeError[] {
                check appendErrors(errors, mergedFields, typeName);
                continue;
            }
            appendHints(hints, mergedFields.hints, typeName);
            supergraphObjectDefinition.fields = mergedFields.result;

            boolean isEverySourceEntity = fieldMapSources
                                            .map(f => f.entityStatus.isEntity)
                                            .reduce(
                                                isolated function (boolean 'final, boolean next) returns boolean => 'final && next,
                                                true);
            if isEverySourceEntity {
                hints = self.filterEntityFieldInconsistencyHints(hints);
            }
        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeInterfaceTypes() returns Hint[]|MergeError[]|InternalError {
        Hint[] hints = [];
        MergeError[] errors = [];
        map<parser:__Type> supergraphInterfaceTypes = self.getSupergraphTypesOfKind(parser:INTERFACE);
        foreach [string, parser:__Type] [typeName, interface] in supergraphInterfaceTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            DescriptionSource[] descriptionSourcecs = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSourcecs.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, typeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSourcecs);
            interface.description = descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);

           FieldMapSource[] fieldMaps = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__Type subgraphType = subgraph.schema.types.get(typeName);
                map<parser:__Field>? subgraphFields = subgraphType.fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMaps.push({
                        subgraph: subgraph.name, 
                        definition: subgraphFields,
                        isDefiningTypeShareable: !subgraph.isFederation2Subgraph || self.isTypeAllowsMergingFields(subgraphType),
                        entityStatus: { isEntity: false, isResolvable: false, keyFields: [] }
                   });
                }
            }
            FieldMapMergeResult|MergeError[] mergedFields = check self.mergeFields(fieldMaps);
            if mergedFields is MergeError[] {
                check appendErrors(errors, mergedFields, typeName);
                continue;
            }
            interface.fields = mergedFields.result;

            interface.possibleTypes = [];
        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeInputTypes() returns Hint[]|MergeError[]|InternalError {
        map<parser:__Type> supergraphInputTypes = self.getSupergraphTypesOfKind(parser:INPUT_OBJECT);
        Hint[] hints = [];
        MergeError[] errors = [];

        foreach [string, parser:__Type] [inputTypeName, 'type] in supergraphInputTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(inputTypeName);

            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, inputTypeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            'type.description = descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, inputTypeName);

            InputFieldMapSource[] inputFieldSources = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__InputValue>? subgraphFields = getTypeFromSchema(subgraph.schema, inputTypeName).inputFields;
                if subgraphFields is map<parser:__InputValue> {
                    inputFieldSources.push({
                        subgraph: subgraph.name,
                        definition: subgraphFields
                    });
                }
            }
            InputValueMapMergeResult|MergeError[] mergedArgResult = check self.mergeInputValues(inputFieldSources, true);
            if mergedArgResult is MergeError[] {
                check appendErrors(errors, mergedArgResult, inputTypeName);
                continue;
            }
            map<parser:__InputValue> mergedFields = mergedArgResult.result;
            'type.inputFields = mergedFields;
            appendHints(hints, mergedArgResult.hints, inputTypeName);

        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeEnumTypes() returns Hint[]|MergeError[]|InternalError {
        MergeError[] errors = [];
        Hint[] hints = [];
        map<parser:__Type> supergraphEnumTypes = self.getSupergraphTypesOfKind(parser:ENUM);

        foreach [string, parser:__Type] [typeName, mergedType] in supergraphEnumTypes.entries() {
            if isSubgraphFederationType(typeName) {
                continue;
            }
            
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);
            EnumTypeUsage usage = self.getEnumTypeUsage(mergedType);

            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, typeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);

            EnumValueSetSource[] enumValueSources = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__EnumValue[]? enumValues = getTypeFromSchema(subgraph.schema, typeName).enumValues;
                if enumValues is parser:__EnumValue[] {
                    enumValueSources.push({
                        subgraph: subgraph.name,
                        definition: enumValues
                    });
                } else {
                    return error InternalError("Invalid enum type");
                }
            }
            EnumValuesMergeResult|MergeError[] mergedEnumValuesResult = check self.mergeEnumValues(enumValueSources, usage);
            if mergedEnumValuesResult is MergeError[] {
                check appendErrors(errors, mergedEnumValuesResult, typeName);
                continue;
            }
            mergedType.enumValues = mergedEnumValuesResult.result;

        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeScalarTypes() returns Hint[]|InternalError {
        Hint[] hints = [];
        map<parser:__Type> supergraphScalarTypes = self.getSupergraphTypesOfKind(parser:SCALAR);

        foreach [string, parser:__Type] [typeName, mergedType] in supergraphScalarTypes.entries() {
            if isSubgraphFederationType(typeName) || parser:isBuiltInType(typeName) {
                continue;
            }
            
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push({
                    subgraph: subgraph.name,
                    definition: getTypeFromSchema(subgraph.schema, typeName).description
                });
            }
            DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);
        }
        return hints;
    }

    isolated function mergeDescription(DescriptionSource[] sources) returns DescriptionMergeResult {
        map<DescriptionSourceGroup> sourceGroups = {};
        foreach DescriptionSource descriptionSource in sources {
            string? description = descriptionSource.definition;
            if description is () || description == "" {
                continue;
            }
            if !sourceGroups.hasKey(description) {
                sourceGroups[description] = { definition: description, subgraphs: [descriptionSource.subgraph] };
            } else {
                sourceGroups.get(description).subgraphs.push(descriptionSource.subgraph);
            }
        }

        Hint[] hints = [];
        string? mergedDescription = ();
        if sourceGroups.length() === 1 { 
            mergedDescription = sourceGroups.get(sourceGroups.keys()[0]).definition;
        } else if sourceGroups.length() > 1 {
            HintDetail[] hintDetails = [];
            foreach DescriptionSourceGroup descriptionSource in sourceGroups {
                if mergedDescription is () && descriptionSource.definition !is () {
                    mergedDescription = descriptionSource.definition;
                }

                hintDetails.push({
                    value: descriptionSource.definition,
                    consistentSubgraphs: descriptionSource.subgraphs,
                    inconsistentSubgraphs: []
                });
            }
            hints.push({
                code: INCONSISTENT_DESCRIPTION,
                location: [],
                details: hintDetails
            });
        }

        return {
            result: mergedDescription,
            hints: hints
        };
    }

    isolated function mergeEnumValues(EnumValueSetSource[] sources, EnumTypeUsage usage) returns EnumValuesMergeResult|MergeError[]|InternalError {
        map<EnumValueSource[]> unionedEnumValues = {}; 
        foreach EnumValueSetSource enumValueSetSource in sources {
            foreach parser:__EnumValue enumValue in enumValueSetSource.definition {
                if unionedEnumValues.hasKey(enumValue.name) {
                    unionedEnumValues.get(enumValue.name).push({
                        subgraph: enumValueSetSource.subgraph,
                        definition: enumValue
                    });
                } else {
                    unionedEnumValues[enumValue.name] = [{
                        subgraph: enumValueSetSource.subgraph,
                        definition: enumValue
                    }];
                }
            }
        }

        MergeError[] errors = [];

        map<EnumValueSource[]>|MergeError[] filteredEnumValues = self.filterEnumValuesBasedOnUsage(
                                                                        sources.map(s => s.subgraph),
                                                                        unionedEnumValues,
                                                                        usage);
        if filteredEnumValues is MergeError[] {
            check appendErrors(errors, filteredEnumValues);
            return errors;
        }

        parser:__EnumValue[] mergedEnumValues = [];
        foreach [string, EnumValueSource[]] [valueName, enumValueSources] in filteredEnumValues.entries() {
            DescriptionSource[] descriptionSources = [];
            DeprecationSource[] deprecationSources = [];
            string[] definingSubgraphs = [];

            foreach EnumValueSource enumValueSource in enumValueSources {
                definingSubgraphs.push(enumValueSource.subgraph);
                descriptionSources.push({
                    subgraph: enumValueSource.subgraph, 
                    definition: enumValueSource.definition.description
                });
                deprecationSources.push({
                    subgraph: enumValueSource.subgraph, 
                    definition: [enumValueSource.definition.isDeprecated, enumValueSource.definition.deprecationReason]
                });
            }

            DescriptionMergeResult mergedDesc = self.mergeDescription(descriptionSources);
            // Handle deprecations

            parser:__EnumValue mergedEnumValue = {
                name: valueName,
                description: mergedDesc.result
            };

            check self.applyJoinEnumDirective(mergedEnumValue, definingSubgraphs);

            mergedEnumValues.push(mergedEnumValue);
        }

        return {
            result: mergedEnumValues,
            hints: []
        };
    }

    isolated function filterEnumValuesBasedOnUsage(
                                          string[] sources, map<EnumValueSource[]> allEnumValues, 
                                          EnumTypeUsage usage
                                        ) returns map<EnumValueSource[]>|MergeError[] {
        
        MergeError[] errors = [];
        map<EnumValueSource[]> filteredEnumValues = {};
        if usage.isUsedInInputs && usage.isUsedInOutputs {
            // Enum values must be exact
            string[] inconsistentEnumValues = [];
            foreach [string, EnumValueSource[]] [value, definingSubgraphs] in allEnumValues.entries() {
                if definingSubgraphs.length() != sources.length() {
                    inconsistentEnumValues.push(value);
                }
            }
            if inconsistentEnumValues.length() === 0 {
                filteredEnumValues = allEnumValues;
            } else {
                foreach string enumValue in inconsistentEnumValues {
                    string[] consistentSubgraphs = allEnumValues.get(enumValue).map(v => v.subgraph);
                    string[] inconsistentSubgraphs = self.getInconsistentSubgraphs(sources, consistentSubgraphs);
                    errors.push(error MergeError("Inconsistent Enum value", hint = {
                        code: ENUM_VALUE_MISMATCH,
                        location: [],
                        details: [{
                            value: enumValue,
                            consistentSubgraphs: consistentSubgraphs,
                            inconsistentSubgraphs: inconsistentSubgraphs
                        }]
                    }));
                }
            }
        } else if usage.isUsedInInputs && !usage.isUsedInOutputs {
            // Enum values must be intersected
            foreach [string, EnumValueSource[]] [enumValueName, definingSubgraphs] in allEnumValues.entries() {
                if definingSubgraphs.length() == sources.length() {
                    filteredEnumValues[enumValueName] = definingSubgraphs;
                }
            }
        } else if !usage.isUsedInInputs && usage.isUsedInOutputs {
            // Enum values must be union
            filteredEnumValues = allEnumValues;
        } else {
            // Enum values must be union, but hint about not using
            filteredEnumValues = allEnumValues;
            // Hint about not using this enum definition in any of the inputs/outputs
        }

        return errors.length() > 0 ? errors : filteredEnumValues;
    }

    isolated function mergeFields(FieldMapSource[] sources) returns FieldMapMergeResult|MergeError[]|InternalError {
        map<FieldSource[]> fieldDefinitions = self.mapFieldsByFieldName(sources);

        MergeError[] errors = [];
        check self.validateFieldMergeability(fieldDefinitions, errors);

        Hint[] hints = [];
        map<parser:__Field> mergedFields = {};
        foreach [string, FieldSource[]] [fieldName, fieldSources] in fieldDefinitions.entries() {
            InputFieldMapSource[] inputFieldSources = [];
            DescriptionSource[] descriptionSources = [];
            DeprecationSource[] deprecationSources = [];
            TypeReferenceSource[] outputTypes = [];

            foreach FieldSource fieldSource in fieldSources {
                inputFieldSources.push({
                    subgraph: fieldSource.subgraph,
                    definition: fieldSource.definition.args
                });
                descriptionSources.push({
                    subgraph: fieldSource.subgraph,
                    definition: fieldSource.definition.description
                });
                deprecationSources.push({
                    subgraph: fieldSource.subgraph,
                    definition: [ fieldSource.definition.isDeprecated, fieldSource.definition.deprecationReason ]
                });
                outputTypes.push({
                    subgraph: fieldSource.subgraph,
                    definition: fieldSource.definition.'type
                });
            }

            InputValueMapMergeResult|MergeError[] mergedArgResult = check self.mergeInputValues(inputFieldSources);
            if mergedArgResult is MergeError[] {
                check appendErrors(errors, mergedArgResult, fieldName);
                continue;
            }
            appendHints(hints, mergedArgResult.hints, fieldName);

            DescriptionMergeResult mergeDescriptionResult = self.mergeDescription(descriptionSources);
            appendHints(hints, mergeDescriptionResult.hints, fieldName);

            TypeReferenceMergeResult|MergeError|InternalError typeMergeResult = self.mergeTypeReferenceSet(outputTypes, "OUTPUT");
            if typeMergeResult is MergeError {
                check appendErrors(errors, [typeMergeResult], fieldName);
                continue;
            }                
            if typeMergeResult is InternalError {
                return typeMergeResult;
            }
            appendHints(hints, typeMergeResult.hints, fieldName);
            parser:__Type mergedOutputType = <parser:__Type>typeMergeResult.result;

            parser:__Field mergedField = {
                name: fieldName,
                args: mergedArgResult.result,
                description: mergeDescriptionResult.result,
                'type: mergedOutputType
            };

            string[] consistentSubgraphs = fieldSources.map(f => f.subgraph);
            string[] inconsistentSubgraphs = self.getInconsistentSubgraphs(sources.map(f => f.subgraph), consistentSubgraphs);
            if inconsistentSubgraphs.length() != 0 { // Add hints only if there are inconsistencies
                hints.push({
                    code: INCONSISTENT_TYPE_FIELD,
                    location: [fieldName],
                    details: [{
                        value: fieldName,
                        inconsistentSubgraphs: inconsistentSubgraphs,
                        consistentSubgraphs: consistentSubgraphs
                    }]
                });
            }

            check self.applyJoinFieldDirectives(
                mergedField.appliedDirectives, 
                consistentSubgraphs = fieldSources.'map(f => f.subgraph),
                hasInconsistentFields = fieldDefinitions.get(fieldName).length() != sources.length(),
                outputTypeMismatches = typeMergeResult.sources
            );

            mergedFields[mergedField.name] = mergedField;

        }

        return errors.length() > 0 ? errors : { result: mergedFields, hints: hints };
        
    }

    isolated function mapFieldsByFieldName(FieldMapSource[] sources) returns map<FieldSource[]> {
        map<FieldSource[]> unionedFields = {};
        foreach FieldMapSource fieldMapSource in sources {
            foreach [string, parser:__Field] [fieldName, fieldValue] in fieldMapSource.definition.entries() {
                boolean isEntityField = fieldMapSource.entityStatus.keyFields.indexOf(fieldName) !is ();
                if !unionedFields.hasKey(fieldName) {
                    unionedFields[fieldName] = [{
                        subgraph: fieldMapSource.subgraph, 
                        definition: fieldValue, 
                        isAllowedToMerge: fieldMapSource.isDefiningTypeShareable || isEntityField
                    }];
                } else { 
                    unionedFields.get(fieldName).push({
                        subgraph: fieldMapSource.subgraph,
                        definition: fieldValue, 
                        isAllowedToMerge: fieldMapSource.isDefiningTypeShareable || isEntityField
                    });
                }
            }
        }
        return unionedFields;
    }

    isolated function validateFieldMergeability(map<FieldSource[]> unionedFields, MergeError[] mergeErrors) returns InternalError? {
        foreach [string, FieldSource[]] [fieldName, fieldSources] in unionedFields.entries() {
            string[] shareableSubgraphs = [];
            string[] nonShareableSubgraphs = [];
            foreach FieldSource fieldSource in fieldSources {
                if fieldSource.isAllowedToMerge || self.isShareableOnField(fieldSource.definition) {
                    shareableSubgraphs.push(fieldSource.subgraph);
                } else {
                    nonShareableSubgraphs.push(fieldSource.subgraph);
                }
            }
            if fieldSources.length() > 1 && shareableSubgraphs.length() !== fieldSources.length() {
                _ = unionedFields.remove(fieldName);
                check appendErrors(mergeErrors, [error MergeError("Invalid field sharing", hint = {
                    code: INVALID_FIELD_SHARING,
                    location: [],
                    details: [{
                        value: "shareable",
                        consistentSubgraphs: shareableSubgraphs,
                        inconsistentSubgraphs: nonShareableSubgraphs
                    }]
                })], fieldName);
            }
        }
    }

    isolated function mergePossibleTypes(PossibleTypesSource[] sources) returns PossibleTypesMergeResult|InternalError {
        map<TypeReferenceSource[]> typeReferenceSourcesByName = check self.mapPossibleTypesByTypeName(sources);

        map<parser:__Type> mergedPossibleTypes = {};
        foreach string typeName in typeReferenceSourcesByName.keys() {
            mergedPossibleTypes[typeName] = check self.getTypeFromSupergraph(typeName);
        }

        Hint[] hints = [];
        TypeReferenceSourceGroup[] typeReferenceSources = [];
        foreach [string, TypeReferenceSource[]] [typeName, definingSources] in typeReferenceSourcesByName.entries() {
            string[] consistentSubgraphs = definingSources.map(s => s.subgraph);
            string[] inconsistentSubgraphs = self.getInconsistentSubgraphs(sources.map(s => s.subgraph), consistentSubgraphs);
            if inconsistentSubgraphs.length() != 0 {
                hints.push({
                    code: INCONSISTENT_UNION_MEMBER,
                    location: [],
                    details: [{
                        value: typeName,
                        inconsistentSubgraphs: inconsistentSubgraphs,
                        consistentSubgraphs: consistentSubgraphs
                    }]
                });
            }

            typeReferenceSources.push({
                definition: mergedPossibleTypes.get(typeName),
                subgraphs: consistentSubgraphs
            });
        }

        return {
            result: mergedPossibleTypes.toArray(),
            sources: typeReferenceSources,
            hints: hints
        };
    }

    isolated function mapPossibleTypesByTypeName(PossibleTypesSource[] sources) returns map<TypeReferenceSource[]>|InternalError {
        map<TypeReferenceSource[]> typeReferenceSourcesByName = {};
        foreach PossibleTypesSource possibleTypeSource in sources {
            foreach parser:__Type possibleType in possibleTypeSource.definition {
                string? possibleTypeName = possibleType.name;
                if possibleTypeName is () {
                    continue;
                }
                
                if typeReferenceSourcesByName.hasKey(possibleTypeName) {
                    typeReferenceSourcesByName.get(possibleTypeName).push({
                        subgraph: possibleTypeSource.subgraph, 
                        definition: possibleType 
                    });
                } else {
                    typeReferenceSourcesByName[possibleTypeName] = [{
                        subgraph: possibleTypeSource.subgraph, 
                        definition: possibleType
                    }];
                }
            }
        }
        return typeReferenceSourcesByName;
    }

    isolated function mergeInputValues(InputFieldMapSource[] sources, boolean isTypeInputType = false) returns InputValueMapMergeResult|MergeError[]|InternalError {
        map<InputValueSource[]> unionedInputs = self.mapInputValuesByInputValueName(sources);

        Hint[] hints = [];
        MergeError[] errors = [];
        map<parser:__InputValue> mergedArguments = {};
        foreach [string, InputValueSource[]] [argName, argDefs] in unionedInputs.entries() {
            if argDefs.length() == sources.length() { // Arguments that are defined in all subgraphs
                DescriptionSource[] descriptionSources = [];
                DefaultValueSource[] defaultValueSources = [];
                TypeReferenceSource[] typeReferenceSources = [];
                foreach InputValueSource inputValueSource in argDefs {
                    descriptionSources.push({
                        subgraph: inputValueSource.subgraph,
                        definition: inputValueSource.definition.description
                    });
                    defaultValueSources.push({
                        subgraph: inputValueSource.subgraph,
                        definition: inputValueSource.definition.defaultValue
                    });
                    typeReferenceSources.push({
                        subgraph: inputValueSource.subgraph,
                        definition: inputValueSource.definition.'type
                    });
                }

                TypeReferenceMergeResult|MergeError|InternalError inputTypeMergeResult = self.mergeTypeReferenceSet(typeReferenceSources, "INPUT");
                if inputTypeMergeResult is MergeError {
                    check appendErrors(errors, [inputTypeMergeResult], argName);
                    continue;
                }
                if inputTypeMergeResult is InternalError {
                    return inputTypeMergeResult;
                }
                parser:__Type mergedTypeReference = <parser:__Type>inputTypeMergeResult.result;
                appendHints(hints, inputTypeMergeResult.hints, argName);

                DefaultValueMergeResult|MergeError defaultValueMergeResult = self.mergeDefaultValues(defaultValueSources);
                if defaultValueMergeResult is MergeError {
                    check appendErrors(errors, [defaultValueMergeResult], argName);
                    continue;
                }               
                appendHints(hints, defaultValueMergeResult.hints, argName);
                anydata? mergedDefaultValue = defaultValueMergeResult.result;

                DescriptionMergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
                appendHints(hints, descriptionMergeResult.hints, argName);

                parser:__InputValue mergedInputField = {
                    name: argName, 
                    'type: mergedTypeReference,
                    description: descriptionMergeResult.result, 
                    defaultValue: mergedDefaultValue 
                };

                if isTypeInputType {
                    check self.applyJoinFieldDirectives(
                        mergedInputField.appliedDirectives, 
                        consistentSubgraphs = argDefs.'map(a => a.subgraph),
                        hasInconsistentFields = false,
                        outputTypeMismatches = inputTypeMergeResult.sources
                    );
                }

                mergedArguments[argName] = mergedInputField;
                
            } else {
                string[] consistentSubgraphs = argDefs.map(a => a.subgraph);
                string[] inconsistentSubgraphs = self.getInconsistentSubgraphs(sources.map(s => s.subgraph), consistentSubgraphs);
                Hint hint = {
                    code: INCONSISTENT_ARGUMENT_PRESENCE,
                    location: [],
                    details: [{
                        value: argName,
                        consistentSubgraphs: consistentSubgraphs,
                        inconsistentSubgraphs: inconsistentSubgraphs
                    }]
                };
                hints.push(hint);

                boolean isRequiredTypeFound = argDefs.some(a => isTypeRequired(a.definition.'type));
                if isRequiredTypeFound {
                    hint.code = REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH;
                    errors.push(error MergeError("Required argument is missing on some subgraph(s)", hint = hint));
                }
            }
        }

        return errors.length() > 0 ? errors : { result: mergedArguments, hints: hints };
    }

    isolated function mapInputValuesByInputValueName(InputFieldMapSource[] sources) returns map<InputValueSource[]> {
        map<InputValueSource[]> unionedInputs = {};
        foreach InputFieldMapSource inputValueMapSource in sources {
            foreach parser:__InputValue arg in inputValueMapSource.definition {
                if unionedInputs.hasKey(arg.name) {
                    unionedInputs.get(arg.name).push({
                        subgraph: inputValueMapSource.subgraph,
                        definition: arg
                    });
                } else {
                    unionedInputs[arg.name] = [{
                        subgraph: inputValueMapSource.subgraph,
                        definition: arg
                    }];
                }
            }
        }
        return unionedInputs;
    }

    isolated function mergeDefaultValues(DefaultValueSource[] sources) returns DefaultValueMergeResult|MergeError {
        map<DefaultValueSourceGroup> unionedDefaultValues = {};
        foreach DefaultValueSource defaultValueSource in sources {
            string? valueString = defaultValueSource.definition.toString();
            if valueString is string {
                if unionedDefaultValues.hasKey(valueString) {
                    unionedDefaultValues.get(valueString).subgraphs.push(defaultValueSource.subgraph);
                } else {
                    unionedDefaultValues[valueString] = { definition: defaultValueSource.definition, subgraphs: [ defaultValueSource.subgraph ] };
                }
            }
        }

        if unionedDefaultValues.length() == 1 {
            string defaultValueKey = unionedDefaultValues.keys()[0];
            return {
                result: unionedDefaultValues.get(defaultValueKey).definition,
                hints: []
            };
        } else if unionedDefaultValues.length() == 2 && unionedDefaultValues.keys().indexOf("") !is () {
            string defaultValueKey = "";

            HintDetail[] details = [];
            foreach [string, DefaultValueSourceGroup] [key, value] in unionedDefaultValues.entries() {
                details.push({
                    consistentSubgraphs: value.subgraphs,
                    value:  key,
                    inconsistentSubgraphs: []
                });
            }

            Hint hint = {
                code: INCONSISTENT_DEFAULT_VALUE_PRESENCE,
                location: [],
                details: details
            };
            return {
                result: unionedDefaultValues.get(defaultValueKey).definition,
                hints: [hint]
            };
        } else {
            HintDetail[] details = [];
            foreach DefaultValueSourceGroup sourceGroup in unionedDefaultValues {
                details.push({
                    value: sourceGroup.definition,
                    consistentSubgraphs: sourceGroup.subgraphs,
                    inconsistentSubgraphs: []
                });
            }
            return error MergeError("Default value mismatch", hint = {
                code: DEFAULT_VALUE_MISMATCH,
                location: [],
                details: details
            });
        }
    
    }

    isolated function mergeTypeReferenceSet(TypeReferenceSource[] sources, "INPUT"|"OUTPUT" refType) returns TypeReferenceMergeResult|MergeError|InternalError {
        map<TypeReferenceSourceGroup> unionedReferences = {};
        foreach TypeReferenceSource typeReferenceSource in sources {
            string key = check typeReferenceToString(typeReferenceSource.definition);

            if !unionedReferences.hasKey(key) {
                unionedReferences[key] = { 
                    definition: typeReferenceSource.definition,
                    subgraphs: [ typeReferenceSource.subgraph ]
                 };
            } else {
                unionedReferences.get(key).subgraphs.push(typeReferenceSource.subgraph);
            }
        }

        Hint[] hints = [];
        HintCode code = refType == "OUTPUT" ? INCONSISTENT_BUT_COMPATIBLE_OUTPUT_TYPE : INCONSISTENT_BUT_COMPATIBLE_INPUT_TYPE;
        parser:__Type? mergedTypeReference = ();
        foreach TypeReferenceSourceGroup ref in unionedReferences {
            parser:__Type typeReference = ref.definition;
            if mergedTypeReference is () {
                mergedTypeReference = typeReference;
            }
            
            if mergedTypeReference !is () {
                parser:__Type?|MergeError|InternalError result = refType == "OUTPUT" ? 
                                        self.getMergedOutputTypeReference(mergedTypeReference, typeReference) :
                                        self.getMergedInputTypeReference(mergedTypeReference, typeReference);
                if result is MergeError {
                    HintDetail[] details = [];
                    foreach [string, TypeReferenceSourceGroup] [typeName, typeSources] in unionedReferences.entries() {
                        details.push({
                            value: typeName,
                            consistentSubgraphs: typeSources.subgraphs,
                            inconsistentSubgraphs: []
                        });
                    }
                    Hint|error hint = result.detail().hint.cloneWithType();
                    if hint is error {
                        return error InternalError(hint.message());
                    }
                    hint.details = details;
                    return error MergeError(result.message(), hint = hint);
                }
                if result is InternalError {
                    return result;
                }
                mergedTypeReference = result;
            }
        }
        if mergedTypeReference is () {
            return error InternalError("Type reference cannot be null");
        }

        TypeReferenceSourceGroup[] typeRefs = [];
        if unionedReferences.length() > 1 {
            HintDetail[] details = [];
            foreach [string, TypeReferenceSourceGroup] [key, mismatch] in unionedReferences.entries() {
                details.push({
                    value: key,
                    consistentSubgraphs: mismatch.subgraphs,
                    inconsistentSubgraphs: []
                });
                typeRefs.push({
                    definition: mismatch.definition,
                    subgraphs: mismatch.subgraphs
                });
            }
            hints.push({
                code: code,
                details: details,
                location: []
            });
        }

        
        return {
            result: mergedTypeReference,
            hints: hints,
            sources: typeRefs
        };
        
    }

    isolated function getMergedOutputTypeReference(parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError {
        parser:__Type? typeAWrappedType = typeA.ofType;
        parser:__Type? typeBWrappedType = typeB.ofType;

        if typeAWrappedType is () && typeBWrappedType is () {
            if typeA.name == typeB.name {
                return check self.getTypeFromSupergraph(typeA.name);
            }
            
            parser:__Type? mutualType = getMutualType(typeA, typeB);
            if mutualType !is () {
                return self.getTypeFromSupergraph(mutualType.name);
            }
        } else if typeAWrappedType !is () && typeBWrappedType !is () && typeA.kind == typeB.kind {
            return parser:wrapType(
                check self.getMergedOutputTypeReference(typeAWrappedType, typeBWrappedType),
                <parser:WRAPPING_TYPE>typeA.kind
            );
        } else if typeBWrappedType !is () && typeB.kind == parser:NON_NULL {
            return check self.getMergedOutputTypeReference(typeA, typeBWrappedType);
        } else if typeAWrappedType !is () && typeA.kind == parser:NON_NULL {
            return check self.getMergedOutputTypeReference(typeAWrappedType, typeB);
        } 
        return error MergeError("Output Type reference Mismatch", hint = {
            code: OUTPUT_TYPE_MISMATCH,
            location: [],
            details: []
        });
        
    }

    isolated function getMergedInputTypeReference(parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError {
        parser:__Type? typeAWrappedType = typeA.ofType;
        parser:__Type? typeBWrappedType = typeB.ofType;

        if typeAWrappedType is () && typeBWrappedType is () && typeA.name == typeB.name {
            return check self.getTypeFromSupergraph(typeA.name);
        } else if typeAWrappedType !is () && typeBWrappedType !is () && typeA.kind == typeB.kind {
            return parser:wrapType(
                check self.getMergedInputTypeReference(typeAWrappedType, typeBWrappedType),
                <parser:WRAPPING_TYPE>typeA.kind
            );
        } else if typeBWrappedType !is () && typeB.kind == parser:NON_NULL {
            return parser:wrapType(
                check self.getMergedInputTypeReference(typeA, typeBWrappedType), 
                parser:NON_NULL
            );
        } else if typeAWrappedType !is () && typeA.kind == parser:NON_NULL {
            return parser:wrapType(
                check self.getMergedInputTypeReference(typeAWrappedType, typeB),
                parser:NON_NULL
            );
        } else {
            return error MergeError("Input Type reference Mismatch", hint = {
                code: INPUT_TYPE_MISMATCH,
                location: [],
                details: []
            });
        }
    }

    isolated function addTypeToSupergraph(parser:__Type 'type) returns InternalError? {
        check addTypeDefinition(self.supergraph.schema, 'type);
    }

    isolated function addDirectiveToSupergraph(parser:__Directive directive) {
        addDirectiveDefinition(self.supergraph.schema, directive);
    }

    isolated function populateRootTypes() returns InternalError? {
        if self.isTypeOnSupergraph(parser:MUTATION_TYPE) {
            self.supergraph.schema.mutationType = check self.getTypeFromSupergraph(parser:MUTATION_TYPE);
        }
        if self.isTypeOnSupergraph(parser:SUBSCRIPTION_TYPE) {
            self.supergraph.schema.mutationType = check self.getTypeFromSupergraph(parser:SUBSCRIPTION_TYPE);
        }
    }

    isolated function filterRootTypeHints(Hint[] hints) returns Hint[] {
        return hints.filter(isolated function(Hint hint) returns boolean => 
                                            !(hint.location.length() > 0 && 
                                              parser:isRootOperationType(hint.location[0]) && 
                                              hint.code is INCONSISTENT_TYPE_FIELD | INCONSISTENT_DESCRIPTION));
    }

    isolated function filterEntityFieldInconsistencyHints(Hint[] hints) returns Hint[] {
        return hints.filter(isolated function(Hint hint) returns boolean => 
                                            hint.code !is INCONSISTENT_TYPE_FIELD);
    }

    isolated function applyLinkDirective(parser:__Schema schema, string url, LinkPurpose? for = ()) returns InternalError? {
        map<anydata> argMap = {
            [URL_FIELD]: url
        };

        if for !is () {
            parser:__EnumValue[]? enumValues = (check self.getTypeFromSupergraph(LINK_PURPOSE_TYPE)).enumValues;
            if enumValues !is parser:__EnumValue[] {
                return error InternalError(string `${LINK_PURPOSE_TYPE} cannot be empty`);
            }
            parser:__EnumValue[] enumValue = enumValues.filter(v => v.name === for);
            if enumValue.length() !== 1 {
                return error InternalError(string `${LINK_PURPOSE_TYPE} cannot have multiple values`);
            }
            argMap[FOR_FIELD] = enumValue[0];
        }

        schema.appliedDirectives.push(
            check self.getAppliedDirectiveFromName(LINK_DIR, argMap)
        );
    }

    isolated function applyJoinTypeDirectives() returns error? {
        foreach [string, parser:__Type] [key, 'type] in self.supergraph.schema.types.entries() {
            if isSubgraphFederationType(key) || parser:isBuiltInType(key) {
                continue;
            }

            foreach Subgraph subgraph in self.subgraphs {
                if subgraph.schema.types.hasKey(key) {
                    map<anydata> argMap = {
                        [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name) 
                    };

                    parser:__Type subgraphType = subgraph.schema.types.get(key);

                    EntityStatus entityStatus = check self.isEntity(subgraphType);
                    if entityStatus.isEntity {
                        argMap[KEY_FIELD] = string:'join(" ", ...entityStatus.keyFields);
                        argMap[RESOLVABLE_FIELD] = entityStatus.isResolvable;
                    }

                    'type.appliedDirectives.push(
                        check self.getAppliedDirectiveFromName(JOIN_TYPE_DIR, argMap)
                    );
                }
            }
        }
    }

    isolated function applyJoinFieldDirectives(parser:__AppliedDirective[] appliedDirs, string[] consistentSubgraphs, 
                                      boolean hasInconsistentFields, TypeReferenceSourceGroup[] outputTypeMismatches) returns InternalError? {

        map<map<anydata>> joinFieldArgs = {};
        if hasInconsistentFields {
            foreach string subgraph in consistentSubgraphs {
                joinFieldArgs[subgraph][GRAPH_FIELD] = self.joinGraphMap.get(subgraph);
            }
        }

        foreach TypeReferenceSourceGroup ref in outputTypeMismatches {
            foreach string subgraph in ref.subgraphs {
                joinFieldArgs[subgraph][GRAPH_FIELD] = self.joinGraphMap.get(subgraph);
                joinFieldArgs[subgraph][TYPE_FIELD] = check typeReferenceToString(ref.definition);
            }
        }

        map<map<anydata>> sortedJoinFieldArgs = {};
        string[] sortedSubgraphNames = joinFieldArgs.keys().sort(key = string:toLowerAscii);
        foreach string subgraphName in sortedSubgraphNames {
            sortedJoinFieldArgs[subgraphName] = joinFieldArgs.get(subgraphName);
        }

        foreach map<anydata> args in sortedJoinFieldArgs {
            appliedDirs.push(check self.getAppliedDirectiveFromName(JOIN_FIELD_DIR, args));
        }
    }

    isolated function applyJoinImplementsDirective(parser:__Type 'type, Subgraph subgraph, parser:__Type interfaceType) returns InternalError? {
        'type.appliedDirectives.push(
            check self.getAppliedDirectiveFromName(
                JOIN_IMPLEMENTS_DIR,
                { 
                    [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name),
                    [INTERFACE_FIELD]: interfaceType.name
                }
            )
        );
    }

    isolated function applyJoinUnionMember(parser:__Type 'type, string subgraph, parser:__Type unionMember) returns InternalError? {
        'type.appliedDirectives.push(
            check self.getAppliedDirectiveFromName(
                JOIN_UNION_MEMBER_DIR,
                { 
                    [GRAPH_FIELD]: self.joinGraphMap.get(subgraph),
                    [UNION_MEMBER_FIELD]: unionMember.name
                }
            )
        );
    }

    isolated function applyJoinEnumDirective(parser:__EnumValue enumValue, string[] subgraphs) returns InternalError? {
        foreach string subgraph in subgraphs {
            enumValue.appliedDirectives.push(
                check self.getAppliedDirectiveFromName(
                    JOIN_ENUMVALUE_DIR,
                    { 
                        [GRAPH_FIELD]: self.joinGraphMap.get(subgraph)
                    }
                )
            );
        }
    }

    isolated function applyJoinGraph(parser:__EnumValue enumValue, string name, string url) returns InternalError? {
        enumValue.appliedDirectives.push(
            check self.getAppliedDirectiveFromName(
                JOIN_GRAPH_DIR,
                { 
                    [NAME_FIELD]: name,
                    [URL_FIELD]: url
                }
            )
        );
    }

    // Filter out the Subgraphs which defines the given typeName
    isolated function getDefiningSubgraphs(string typeName) returns Subgraph[] {
        Subgraph[] subgraphs = [];
        foreach Subgraph subgraph in self.subgraphs {
            if isTypeOnTypeMap(subgraph.schema, typeName) {
                subgraphs.push(subgraph);
            }
        }

        return subgraphs;
    }

    isolated function getEnumTypeUsage(parser:__Type enumType) returns EnumTypeUsage {
        EnumTypeUsage usage = {
            isUsedInInputs: false,
            isUsedInOutputs: false
        };
        foreach parser:__Type 'type in self.supergraph.schema.types {

            // Stop traversing the typemap if both of usages are true
            if usage.isUsedInInputs && usage.isUsedInOutputs {
                break;
            }

            // Get the enum usage of the current 'type
            map<parser:__Field>? fields = 'type.fields;
            map<parser:__InputValue>? inputFields = 'type.inputFields;
            boolean isUsedInInputs = false;
            boolean isUsedInOutputs = false;
            if fields !is () { // Current type is an Object/Interface
                EnumTypeUsage typeUsage = self.getEnumTypeUsageInFields(enumType, fields);
                isUsedInInputs = typeUsage.isUsedInInputs;
                isUsedInOutputs = typeUsage.isUsedInOutputs;
            } else if inputFields !is () { // Current type is an Input type
                isUsedInInputs = self.getEnumTypeUsageInArgs(enumType, inputFields);
            }

            // Set only if either one of the usages are false.
            if !usage.isUsedInInputs {
                usage.isUsedInInputs = isUsedInInputs;
            }
            if !usage.isUsedInOutputs {
                usage.isUsedInOutputs = isUsedInOutputs;
            }
        }

        return usage;
    }

    isolated function getEnumTypeUsageInFields(parser:__Type enumType, map<parser:__Field> fields) returns EnumTypeUsage {
        EnumTypeUsage usage = {
            isUsedInInputs: false,
            isUsedInOutputs: false
        };
        foreach parser:__Field 'field in fields {
            if usage.isUsedInInputs && usage.isUsedInOutputs {
                break;
            }

            if !usage.isUsedInOutputs {
                parser:__Type|InternalError|MergeError mergedOutputTypeRef = self.getMergedOutputTypeReference(
                                                                                enumType, 
                                                                                'field.'type
                                                                             );
                usage.isUsedInOutputs = mergedOutputTypeRef is parser:__Type;
            }

            if !usage.isUsedInInputs {
                usage.isUsedInInputs = self.getEnumTypeUsageInArgs(enumType, 'field.args);
            }
        }
        return usage;
    }

    isolated function getEnumTypeUsageInArgs(parser:__Type enumType, map<parser:__InputValue> args) returns boolean {
        boolean isUsedInInputs = false;
        foreach parser:__InputValue arg in args {
            if isUsedInInputs {
                break;
            }

            parser:__Type|InternalError|MergeError mergedInputTypeRef = self.getMergedInputTypeReference(
                                                                            enumType,
                                                                            arg.'type
                                                                        );
            isUsedInInputs = mergedInputTypeRef is parser:__Type;
        }
        return isUsedInInputs;
    }

    isolated function getSupergraphTypesOfKind(parser:__TypeKind kind) returns map<parser:__Type> {
        return getTypesOfKind(self.supergraph.schema, kind);
    }

    isolated function getFilteredFields(string typeName, map<parser:__Field> subgraphFields) returns map<parser:__Field>|InternalError {
        map<parser:__Field> filteredFields = {};
        foreach [string, parser:__Field] [key, subgraphField] in subgraphFields.entries() {
            if !(typeName == parser:QUERY_TYPE && isFederationFieldType(key)) {
                filteredFields[key] = subgraphField;
            }
        }
        return filteredFields;
    }

    function getInterfacesArray(parser:__Type[] subgraphInterfaces) returns parser:__Type[]|InternalError {
        parser:__Type[] supergraphInterfaces = [];
        foreach parser:__Type subgraphInterface in subgraphInterfaces {
            supergraphInterfaces.push(
                check self.getTypeFromSupergraph(subgraphInterface.name)
            );
        }

        return supergraphInterfaces;
    }

    function getJoinImplementsAppliedDirectives(Subgraph subgraph, parser:__Type[] interfaces) returns parser:__AppliedDirective[]|InternalError {
        parser:__AppliedDirective[] appliedJoinImplements = [];
        foreach parser:__Type interface in interfaces {
            appliedJoinImplements.push(
                check getAppliedDirectiveFromDirective(
                    check self.getDirectiveFromSupergraph(JOIN_IMPLEMENTS_DIR),
                    { 
                        [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name),
                        "interface": interface.name
                    }
                )
            );
        }
        return appliedJoinImplements;
    }

    function getSupergraphDirectiveDefinition(parser:__Directive subgraphDefinition) returns parser:__Directive {
        return getDirectiveFromDirectiveMap(self.supergraph.schema, subgraphDefinition.name);
    }

    isolated function getTypeFromSupergraph(string? name) returns parser:__Type|InternalError {
        if name is () {
            return error InternalError(string `Type name cannot be null`);
        }
        if self.isTypeOnSupergraph(name) {
            return getTypeFromSchema(self.supergraph.schema, name);
        } else {
            return error InternalError(string `Type '${name}' is not defined in the Supergraph`);
        }
    }

    isolated function isTypeOnSupergraph(string typeName) returns boolean {
        return isTypeOnTypeMap(self.supergraph.schema, typeName);
    }

    isolated function isEntity(parser:__Type 'type) returns EntityStatus|error {
        EntityStatus status = {
            isEntity: false,
            isResolvable: false,
            keyFields: []
        };
        foreach parser:__AppliedDirective appliedDirective in 'type.appliedDirectives {
            if appliedDirective.definition.name == KEY_DIR {
                status.isEntity = true;

                anydata isResolvable = appliedDirective.args.get(RESOLVABLE_FIELD).value;
                if isResolvable is boolean {
                    status.isResolvable = isResolvable;
                } else {
                    return error InternalError("Invalid resolvable value of @key directive");
                }

                anydata fields = appliedDirective.args.get(FIELDS_FIELD).value;
                if fields is string {
                    regexp:RegExp fieldSeperator = re ` `;
                    status.keyFields = fieldSeperator.split(fields);
                } else {
                    return error InternalError("Invalid field set of @key directive");
                }
            }
        }

        return status;
    }

    isolated function getDirectiveFromSupergraph(string name) returns parser:__Directive|InternalError {
        if self.isDirectiveOnSupergraph(name) {
            return getDirectiveFromDirectiveMap(self.supergraph.schema, name);
        } else {
            return error InternalError(string `Directive '${name}' is not defined in the Supergraph`);
        }
    }

    isolated function getAppliedDirectiveFromName(string name, map<anydata> args) returns parser:__AppliedDirective|InternalError {
        return check getAppliedDirectiveFromDirective(
            check self.getDirectiveFromSupergraph(name), args
        );
    }

    isolated function isDirectiveOnSupergraph(string directiveName) returns boolean {
        return isDirectiveOnDirectiveMap(self.supergraph.schema, directiveName);
    }

    isolated function getInputValueMap(map<parser:__InputValue> sub_map) returns map<parser:__InputValue>|InternalError {
        map<parser:__InputValue> inputValueMap = {};
        foreach [string, parser:__InputValue] [key, value] in sub_map.entries() {
            inputValueMap[key] = {
                name: value.name,
                description: value.description,
                'type: check self.getInputTypeFromSupergraph(value.'type),
                appliedDirectives: [],
                defaultValue: value.defaultValue
            };
        }
        return inputValueMap;
    }

    isolated function getInputTypeFromSupergraph(parser:__Type 'type) returns parser:__Type|InternalError {
        if 'type.kind is parser:WRAPPING_TYPE {
            return parser:wrapType(
                check self.getInputTypeFromSupergraph(<parser:__Type>'type.ofType), 
                <parser:WRAPPING_TYPE>'type.kind
            );
        } else {
            return check self.getTypeFromSupergraph(<string>'type.name);
        }
    }

    isolated function isTypeAllowsMergingFields(parser:__Type 'type) returns boolean {
        return self.isShareableOnType('type) || 'type.kind == parser:INTERFACE;
    }

    isolated function isShareableOnType(parser:__Type 'type) returns boolean {
        return isDirectiveApplied('type.appliedDirectives, SHAREABLE_DIR);
    }

    isolated function isShareableOnField(parser:__Field 'field) returns boolean {
        return isDirectiveApplied('field.appliedDirectives, SHAREABLE_DIR);
    }

    isolated function getInconsistentSubgraphs(string[] allPossibleSources, string[] consistentSources) returns string[] {
        string[] inconsistentSubgraphs = [];
        foreach string subgraph in allPossibleSources {
            boolean isConsistentSubgraph = false;
            foreach string consistentSubgraph in consistentSources {
                if subgraph == consistentSubgraph {
                    isConsistentSubgraph = true;
                    break;
                }
            }
            
            if !isConsistentSubgraph {
                inconsistentSubgraphs.push(subgraph);
            }
        }
        return inconsistentSubgraphs;
    }

}
