import graphql_schema_registry.parser;

public class Merger {

    private Supergraph supergraph;
    private map<Subgraph> subgraphs;
    private map<parser:__EnumValue> joinGraphMap;

    public isolated function init(Subgraph[] subgraphs) returns InternalError? {
        self.subgraphs = {};
        foreach Subgraph subgraph in subgraphs {
            Subgraph updatedSubgraph = subgraph.clone();
            updatedSubgraph.isFederation2Subgraph = check isFederation2Subgraph(updatedSubgraph);
            self.subgraphs[subgraph.name] = updatedSubgraph;
        }
        self.joinGraphMap = {};
        self.supergraph = {
            schema: createSchema(),
            subgraphs: self.subgraphs.toArray()
        };
    }

    public isolated function merge() returns SupergraphMergeResult|MergeError[]|InternalError|error {
        check self.addFederationDefinitions();
        check self.populateFederationJoinGraphEnum();
        MergeError[]? shallowTypeMergeResult = check self.addTypesShallow();
        if shallowTypeMergeResult is MergeError[] {
            return transformErrorMessages(shallowTypeMergeResult);
        }
        check self.addDirectives();
        Hint[] unionMergeHints = check self.mergeUnionTypes() ?: [];
        check self.mergeImplementsRelationship();

        Hint[] mergeHints = [];

        Hint[]|MergeError[] objectMergeHints = check self.mergeObjectTypes();
        if objectMergeHints is MergeError[] {
            return transformErrorMessages(objectMergeHints);
        }
        if objectMergeHints is Hint[] {
            mergeHints.push(...objectMergeHints);
        }

        Hint[]|MergeError[] interfaceMergeHints = check self.mergeInterfaceTypes();
        if interfaceMergeHints is MergeError[] {
            return transformErrorMessages(interfaceMergeHints);
        }
        if interfaceMergeHints is Hint[] {
            mergeHints.push(...interfaceMergeHints);
        }

        Hint[]|MergeError[] inputTypeMergeHints = check self.mergeInputTypes();
        if inputTypeMergeHints is MergeError[] {
            return transformErrorMessages(inputTypeMergeHints);
        }
        if inputTypeMergeHints is Hint[] {
            mergeHints.push(...inputTypeMergeHints);
        }
        Hint[] enumTypeMergeHints = check self.mergeEnumTypes() ?: [];
        Hint[] scalarTypeMergeHints = check self.mergeScalarTypes() ?: [];
        check self.applyJoinTypeDirectives();
        check self.populateRootTypes();

        Hint[] hints = [ ...unionMergeHints,
                        //  ...objectMergeHints,
                        //  ...interfaceMergeHints,
                        //  ...inputTypeMergeHints,
                         ...mergeHints,
                         ...enumTypeMergeHints,
                         ...scalarTypeMergeHints ];
        return {
            result: self.supergraph,
            hints: printHints(hints)
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

        map<parser:__Directive> federationDirs = getFederationDirectives(self.supergraph.schema.types);
        foreach parser:__Directive directive in federationDirs {
            self.addDirectiveToSupergraph(directive);
        }

        parser:__Type queryType = check self.getTypeFromSupergraph(parser:QUERY_TYPE);
        map<parser:__Field>? fields = queryType.fields;
        if fields is map<parser:__Field> {
            parser:__Type _serviceType = parser:wrapType(
                                            check self.getTypeFromSupergraph(parser:_SERVICE_TYPE), 
                                            parser:NON_NULL
                                        );

            fields[_SERVICE_FIELD_TYPE] = {
                name: _SERVICE_FIELD_TYPE,
                'type: _serviceType,
                args: {}
            };
        }
        
        check self.applyLinkDirective(self.supergraph.schema, LINK_SPEC_URL);
        check self.applyLinkDirective(self.supergraph.schema, JOIN_SPEC_URL, EXECUTION);
    }

    isolated function populateFederationJoinGraphEnum() returns InternalError? {
        parser:__Type typeFromSupergraph = check self.getTypeFromSupergraph(JOIN_GRAPH_TYPE);
        parser:__EnumValue[]? enumValues = typeFromSupergraph.enumValues;
        if enumValues is parser:__EnumValue[] {
            foreach Subgraph subgraph in self.subgraphs {
                parser:__EnumValue enumValue = {
                    name: subgraph.name.toUpperAscii()
                };
                check self.applyJoinGraph(enumValue, subgraph.name, subgraph.url);

                enumValues.push(enumValue);
                self.joinGraphMap[subgraph.name] = enumValue;
            }
        }
    }

    isolated function addTypesShallow() returns MergeError[]|InternalError? {
        map<map<TypeKindSources>> typeMap = {};
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Type] [typeName, 'type] in subgraph.schema.types.entries() {
                if parser:isBuiltInType(typeName) || isSubgraphFederationType(typeName) {
                    continue;
                }

                parser:__TypeKind typeKind = 'type.kind;
                if typeMap.hasKey(typeName) {
                    map<TypeKindSources> subgraphMap = typeMap.get(typeName);
                    if subgraphMap.hasKey(typeKind) {
                        subgraphMap.get(typeKind).subgraphs.push(subgraph);
                    } else {
                        subgraphMap[typeKind] = {
                            data: typeKind,
                            subgraphs: [ subgraph ]
                        };
                    }
                } else {
                    map<TypeKindSources> subgraphMap = {
                        [typeKind] : {
                            data: typeKind,
                            subgraphs: [ subgraph ]
                        }
                    };
                    typeMap[typeName] = subgraphMap;
                }
            }
        }

        MergeError[] errors = [];
        foreach [string, map<TypeKindSources>] [typeName, typeKindMap] in typeMap.entries() {
            if typeKindMap.length() === 1 {
                check self.addTypeToSupergraph({
                    name: typeName,
                    kind: typeKindMap.toArray()[0].data
                });
            } else {
                HintDetail[] details = [];
                foreach [string, TypeKindSources] [typeKind, subgraphMap] in typeKindMap.entries() {
                    HintDetail mismatchDetail = {
                        value: typeKind,
                        consistentSubgraphs: subgraphMap.subgraphs,
                        inconsistentSubgraphs: []
                    };
                    details.push(mismatchDetail);
                }

                Hint mismatchHint = {
                    code: TYPE_KIND_MISMATCH,
                    location: [ typeName ],
                    details: details
                };
                errors.push(error MergeError("Type kind mismatch", hint = mismatchHint));
            }
        }
        return errors.length() > 0 ? errors : ();
    }

    isolated function addDirectives() returns InternalError? {
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Directive] [key, value] in subgraph.schema.directives.entries() {
                if parser:isBuiltInDirective(key) || !parser:isExecutableDirective(value) || isSubgraphFederationDirective(key) {
                    continue;
                }

                if self.isDirectiveOnSupergraph(key) {
                    // Handle directive conflicts
                }

                self.addDirectiveToSupergraph({
                    name: value.name,
                    locations: check getDirectiveLocationsFromStrings(value.locations),
                    args: check self.getInputValueMap(value.args),
                    isRepeatable: value.isRepeatable
                });
            }
        }
    }

    isolated function mergeUnionTypes() returns Hint[]|InternalError? {
        map<parser:__Type> supergraphUnionTypes = self.getSupergraphTypesOfKind(parser:UNION);
        Hint[] hints = [];
        foreach [string, parser:__Type] [typeName, mergedType] in supergraphUnionTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            // ---------- Merge Descriptions -----------
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            appendHints(hints, descriptionMergeResult.hints, typeName);
            mergedType.description = <string?>descriptionMergeResult.result;

            // ---------- Merge Possible Types -----------
            PossibleTypesSource[] possibleTypesSources = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__Type[]? possibleTypesResult = getTypeFromTypeMap(subgraph.schema, typeName).possibleTypes;
                if possibleTypesResult is parser:__Type[] {
                    possibleTypesSources.push([
                        subgraph,
                        possibleTypesResult
                    ]);
                }
            }
            PossibleTypesMergeResult possibleTypesMergeResult = check self.mergePossibleTypes(possibleTypesSources);
            mergedType.possibleTypes = <parser:__Type[]?>possibleTypesMergeResult.result;
            appendHints(hints, possibleTypesMergeResult.hints, typeName);

            foreach TypeReferenceSources typeRefGrp in possibleTypesMergeResult.sources {
                foreach Subgraph consistentSubgraph in typeRefGrp.subgraphs {
                    check self.applyJoinUnionMember(
                        mergedType,
                        consistentSubgraph,
                        <parser:__Type>typeRefGrp.data
                    );
                }                
            }
        }
        return hints;
    }

    isolated function mergeImplementsRelationship() returns InternalError? {
        check self.mergeImplementsOf(parser:OBJECT);
        check self.mergeImplementsOf(parser:INTERFACE);
    }

    isolated function mergeImplementsOf(parser:__TypeKind kind) returns InternalError? {
        map<parser:__Type> supergraphTypes = self.getSupergraphTypesOfKind(kind);
        foreach [string, parser:__Type] [typeName, 'type] in supergraphTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            'type.interfaces = [];
            check self.mergeInterfaceImplements('type, subgraphs);
        }
    }

    isolated function mergeObjectTypes() returns Hint[]|MergeError|MergeError[]|InternalError {
        map<parser:__Type> supergraphObjectTypes = self.getSupergraphTypesOfKind(parser:OBJECT);
        Hint[] hints = [];
        MergeError[] errors = [];
        foreach [string, parser:__Type] [typeName, 'type] in supergraphObjectTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptionSources = subgraphs.map(s => [s, s.schema.types.get(objectName).description]);
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            appendHints(hints, descriptionMergeResult.hints, typeName);
            'type.description = <string?>descriptionMergeResult.result;

            // ---------- Merge Fields -----------
            FieldMapSource[] fieldMapSources = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__Type subgraphType = subgraph.schema.types.get(typeName);
                map<parser:__Field>? subgraphFields = subgraphType.fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMapSources.push([
                        subgraph, 
                        check self.getFilteredFields(typeName, subgraphFields),
                        !subgraph.isFederation2Subgraph || self.isTypeAllowsMergingFields(subgraphType)
                    ]);
                }
            }
            MergedResult|MergeError[] mergedFields = check self.mergeFields(fieldMapSources);
            if mergedFields is MergeError[] {
                check appendErrors(errors, mergedFields, typeName);
                continue;
            }
            appendHints(hints, mergedFields.hints, typeName);
            'type.fields = <map<parser:__Field>>mergedFields.result;
        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeInterfaceTypes() returns Hint[]|MergeError|MergeError[]|InternalError {
        Hint[] hints = [];
        MergeError[] errors = [];
        map<parser:__Type> supergraphInterfaceTypes = self.getSupergraphTypesOfKind(parser:INTERFACE);
        foreach [string, parser:__Type] [typeName, interface] in supergraphInterfaceTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            DescriptionSource[] descriptionSourcecs = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSourcecs.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSourcecs);
            interface.description = <string?>descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);

            // ---------- Merge Fields -----------
           FieldMapSource[] fieldMaps = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__Type subgraphType = subgraph.schema.types.get(typeName);
                map<parser:__Field>? subgraphFields = subgraphType.fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMaps.push([ 
                        subgraph, 
                        subgraphFields,
                        !subgraph.isFederation2Subgraph || self.isTypeAllowsMergingFields(subgraphType)
                    ]);
                }
            }
            MergedResult|MergeError[] mergedFields = check self.mergeFields(fieldMaps);
            if mergedFields is MergeError[] {
                check appendErrors(errors, mergedFields, typeName);
                continue;
            }
            interface.fields = <map<parser:__Field>>mergedFields.result;

            interface.possibleTypes = [];
        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeInputTypes() returns Hint[]|MergeError|MergeError[]|InternalError {
        map<parser:__Type> supergraphInputTypes = self.getSupergraphTypesOfKind(parser:INPUT_OBJECT);
        Hint[] hints = [];
        MergeError[] errors = [];

        foreach [string, parser:__Type] [inputTypeName, 'type] in supergraphInputTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(inputTypeName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, inputTypeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            'type.description = <string?>descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, inputTypeName);

            // ---------- Merge Input fields -----------
            InputFieldMapSource[] inputFieldSources = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__InputValue>? subgraphFields = getTypeFromTypeMap(subgraph.schema, inputTypeName).inputFields;
                if subgraphFields is map<parser:__InputValue> {
                    inputFieldSources.push([ subgraph, subgraphFields ]);
                }
            }
            MergedResult|MergeError[] mergedArgResult = check self.mergeInputValues(inputFieldSources, true); // Handle INPUT_FIELD_TYPE_MISMATCH
            if mergedArgResult is MergeError[] {
                check appendErrors(errors, mergedArgResult, inputTypeName);
                continue;
            }
            map<parser:__InputValue> mergedFields = <map<parser:__InputValue>>mergedArgResult.result;
            'type.inputFields = mergedFields;
            appendHints(hints, mergedArgResult.hints, inputTypeName);

        }
        return errors.length() > 0 ? errors : hints;
    }

    isolated function mergeEnumTypes() returns Hint[]|InternalError? {
        Hint[] hints = [];
        map<parser:__Type> supergraphEnumTypes = self.getSupergraphTypesOfKind(parser:ENUM);

        foreach [string, parser:__Type] [typeName, mergedType] in supergraphEnumTypes.entries() {
            if isSubgraphFederationType(typeName) {
                continue;
            }
            
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);
            EnumTypeUsage usage = self.getEnumTypeUsage(mergedType);

            // ---------- Merge Descriptions -----------
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = <string?>descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);

            // ---------- Merge Possible Types -----------
            EnumValueSetSource[] enumValueSources = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__EnumValue[]? enumValues = getTypeFromTypeMap(subgraph.schema, typeName).enumValues;
                if enumValues is parser:__EnumValue[] {
                    enumValueSources.push([ subgraph, enumValues ]);
                } else {
                    return error InternalError("Invalid enum type");
                }

                MergeResult? mergedEnumValuesResult = check self.mergeEnumValues(enumValueSources, usage);
                if mergedEnumValuesResult is MergeResult {
                    mergedType.enumValues = <parser:__EnumValue[]?>mergedEnumValuesResult.result;
                }
            }
        }
        return hints;
    }

    isolated function mergeScalarTypes() returns Hint[]|InternalError? {
        Hint[] hints = [];
        map<parser:__Type> supergraphScalarTypes = self.getSupergraphTypesOfKind(parser:SCALAR);

        foreach [string, parser:__Type] [typeName, mergedType] in supergraphScalarTypes.entries() {
            if isSubgraphFederationType(typeName) || parser:isBuiltInType(typeName) {
                continue;
            }
            
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            // ---------- Merge Descriptions -----------
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = <string?>descriptionMergeResult.result;
            appendHints(hints, descriptionMergeResult.hints, typeName);
        }
        return hints;
    }

    isolated function mergeDescription(DescriptionSource[] sources) returns MergedResult {
        DescriptionSources[] sourceGroups = []; // Map cannot be used here because descriptions are Nullable
        foreach int i in 0...sources.length()-1 {
            string? description = sources[i][1];
            Subgraph definingSubgraph = sources[i][0];
            int? index = ();
            foreach int k in 0...sourceGroups.length()-1 {
                if sourceGroups[k].data === description {
                    index = k;
                    break;
                }
            }
            if index !is () {
                sourceGroups[index].subgraphs.push(definingSubgraph);
            } else {
                sourceGroups.push({
                    data: description,
                    subgraphs: [ definingSubgraph ]
                });
            }
        }

        Hint[] hints = [];
        string? mergedDescription = ();
        if sourceGroups.length() === 1 { // Description has inconsistencies
            mergedDescription = sourceGroups[0].data;
        } else {
            HintDetail[] hintDetails = [];
            foreach DescriptionSources descriptionSource in sourceGroups {
                if mergedDescription is () && descriptionSource.data !is () {
                    mergedDescription = descriptionSource.data;
                }

                hintDetails.push({
                    value: descriptionSource.data,
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

    isolated function mergeEnumValues(EnumValueSetSource[] sources, EnumTypeUsage usage) returns MergeResult|InternalError? {
        // Map between Enum value's name and Subgraphs which define that enum value along with it's definition of the enum value
        map<EnumValueSource[]> unionedEnumValues = {}; 
        foreach EnumValueSetSource [subgraph, enumValues] in sources {
            foreach parser:__EnumValue enumValue in enumValues {
                if unionedEnumValues.hasKey(enumValue.name) {
                    unionedEnumValues.get(enumValue.name).push([subgraph, enumValue]);
                } else {
                    unionedEnumValues[enumValue.name] = [[subgraph, enumValue]];
                }
            }
        }

        // Same mapping as above, but filtered according to the merginig stratergy
        map<EnumValueSource[]> filteredEnumValues = self.filterEnumValuesBasedOnUsage(
                                                            unionedEnumValues,
                                                            sources.length(),
                                                            usage
                                                    );

        parser:__EnumValue[] mergedEnumValues = [];
        foreach [string, EnumValueSource[]] [valueName, valueSource] in filteredEnumValues.entries() {
            DescriptionSource[] descriptionSources = [];
            DeprecationSource[] deprecationSources = []; // Handle deprecations
            Subgraph[] definingSubgraphs = [];

            foreach EnumValueSource [subgraph, definition] in valueSource {
                definingSubgraphs.push(subgraph);
                descriptionSources.push([subgraph, definition.description]);
                deprecationSources.push([subgraph, [definition.isDeprecated, definition.deprecationReason]]);
            }

            MergedResult mergedDesc = self.mergeDescription(descriptionSources);
            // Handle deprecations

            parser:__EnumValue mergedEnumValue = {
                name: valueName,
                description: <string?>mergedDesc.result
            };

            check self.applyJoinEnumDirective(mergedEnumValue, definingSubgraphs);

            mergedEnumValues.push(mergedEnumValue);
        }

        return {
            result: mergedEnumValues,
            hints: []
        };
    }

    isolated function filterEnumValuesBasedOnUsage(map<EnumValueSource[]> allEnumValues, 
                                          int contributingSubgraphCount, EnumTypeUsage usage
                                        ) returns map<EnumValueSource[]> {
        map<EnumValueSource[]> filteredEnumValues = {};
        if usage.isUsedInInputs && usage.isUsedInOutputs {
            // Enum values must be exact
            boolean isConsistent = true;
            foreach EnumValueSource[] definingSubgraphs in allEnumValues {
                if definingSubgraphs.length() != contributingSubgraphCount {
                    isConsistent = false;
                    break;
                }
            }
            if isConsistent {
                filteredEnumValues = allEnumValues;
            } else {
                // Handle inconsistent enum value
            }
        } else if usage.isUsedInInputs && !usage.isUsedInOutputs {
            // Enum values must be intersected
            foreach [string, EnumValueSource[]] [enumValueName, definingSubgraphs] in allEnumValues.entries() {
                if definingSubgraphs.length() == contributingSubgraphCount {
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

        return filteredEnumValues;
    }

    isolated function mergeFields(FieldMapSource[] sources) returns MergedResult|MergeError|MergeError[]|InternalError {

        // Get union of all the fields
        map<FieldSource[]> unionedFields = {};
        foreach FieldMapSource [subgraph, subgraphFields, isTypeShareable] in sources {
            foreach [string, parser:__Field] [fieldName, fieldValue] in subgraphFields.entries() {
                if !unionedFields.hasKey(fieldName) {
                    unionedFields[fieldName] = [[subgraph, fieldValue, isTypeShareable]];
                } else { 
                    unionedFields.get(fieldName).push([subgraph, fieldValue, isTypeShareable]);
                }
            }
        }

        foreach [string, FieldSource[]] [fieldName, fieldSources] in unionedFields.entries() {
            Subgraph[] shareableSubgraphs = [];
            Subgraph[] nonShareableSubgraphs = [];
            foreach FieldSource [subgraph, 'field, isTypeShareable] in fieldSources {
                if isTypeShareable || self.isShareableOnField('field) {
                    shareableSubgraphs.push(subgraph);
                } else {
                    nonShareableSubgraphs.push(subgraph);
                }
            }
            if fieldSources.length() > 1 && shareableSubgraphs.length() !== fieldSources.length() {
                _ = unionedFields.remove(fieldName); // Handle shareable error
            }
        }

        Hint[] hints = [];
        MergeError[] errors = [];
        map<parser:__Field> mergedFields = {};
        foreach [string, FieldSource[]] [fieldName, fieldSources] in unionedFields.entries() {
            InputFieldMapSource[] inputFieldSources = [];
            DescriptionSource[] descriptionSources = [];
            DeprecationSource[] deprecationSources = []; // Handle deprecations
            TypeReferenceSource[] outputTypes = [];

            foreach FieldSource [subgraph, mergingField, _] in fieldSources {
                inputFieldSources.push([
                    subgraph,
                    mergingField.args
                ]);
                descriptionSources.push([
                    subgraph,
                    mergingField.description
                ]);
                deprecationSources.push([
                    subgraph,
                    [ mergingField.isDeprecated, mergingField.deprecationReason ]
                ]);
                outputTypes.push([
                    subgraph,
                    mergingField.'type
                ]);
            }

            MergedResult|MergeError[] mergedArgResult = check self.mergeInputValues(inputFieldSources); // Handle FIELD_ARGUMENT_TYPE_MISMATCH
            if mergedArgResult is MergeError[] {
                check appendErrors(errors, mergedArgResult, fieldName);
                continue;
            }
            appendHints(hints, mergedArgResult.hints, fieldName);
            map<parser:__InputValue> mergedArgs = <map<parser:__InputValue>>mergedArgResult.result;

            MergedResult mergeDescriptionResult = self.mergeDescription(descriptionSources);
            appendHints(hints, mergeDescriptionResult.hints, fieldName);
            string? mergedDescription = <string?>mergeDescriptionResult.result;

            TypeReferenceMergeResult|MergeError|InternalError typeMergeResult = self.mergeTypeReferenceSet(outputTypes, OUTPUT);
            if typeMergeResult is MergeError {
                // Handle errors
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
                args: mergedArgs,
                description: mergedDescription,
                'type: mergedOutputType
            };

            ConsistentInconsistenceSubgraphs subgraphs = self.getConsistentInconsistentSubgraphs(sources.map(f => [f[0], f[1]]), fieldSources.map(f => [f[0], f[1]]));
            if subgraphs.inconsistent.length() != 0 { // Add hints only if there are inconsistencies
                hints.push({
                    code: INCONSISTENT_TYPE_FIELD,
                    location: [fieldName],
                    details: [{
                        value: fieldName,
                        inconsistentSubgraphs: subgraphs.inconsistent,
                        consistentSubgraphs: subgraphs.consistent
                    }]
                });
            }

            check self.applyJoinFieldDirectives(
                mergedField.appliedDirectives, 
                consistentSubgraphs = fieldSources.'map(s => s[0]),
                hasInconsistentFields = unionedFields.get(fieldName).length() != sources.length(),
                outputTypeMismatches = typeMergeResult.sources
            );

            mergedFields[mergedField.name] = mergedField;

        }

        return errors.length() > 0 ? errors : { result: mergedFields, hints: hints };
        
    }

    isolated function mergePossibleTypes(PossibleTypesSource[] sources) returns PossibleTypesMergeResult|InternalError {
        map<TypeReferenceSource[]> typeRefMap = {};
        map<parser:__Type> mergedPossibleTypes = {};
        Hint[] hints = [];

        // Get union of possible types across subgraphs
        foreach PossibleTypesSource [subgraph, possibleTypes] in sources {
            foreach parser:__Type possibleType in possibleTypes {
                string? possibleTypeName = possibleType.name;
                if possibleTypeName !is () {
                    mergedPossibleTypes[possibleTypeName] = check self.getTypeFromSupergraph(possibleTypeName);

                    if typeRefMap.hasKey(possibleTypeName) {
                        typeRefMap.get(possibleTypeName).push([subgraph, possibleType]);
                    } else {
                        typeRefMap[possibleTypeName] = [[subgraph, possibleType]];
                    }
                }
            }
        }

        TypeReferenceSources[] typeReferenceSources = [];
        foreach [string, TypeReferenceSource[]] [typeName, references] in typeRefMap.entries() {
            ConsistentInconsistenceSubgraphs subgraphs = self.getConsistentInconsistentSubgraphs(sources, references);

            if subgraphs.inconsistent.length() != 0 { // Add hints only if there are inconsistencies
                hints.push({
                    code: INCONSISTENT_UNION_MEMBER,
                    location: [],
                    details: [{
                        value: typeName,
                        inconsistentSubgraphs: subgraphs.inconsistent,
                        consistentSubgraphs: subgraphs.consistent
                    }]
                });
            }

            typeReferenceSources.push({
                data: mergedPossibleTypes.get(typeName),
                subgraphs: subgraphs.consistent
            });
        }

        return {
            result: mergedPossibleTypes.toArray(),
            sources: typeReferenceSources,
            hints: hints
        };
    }

    isolated function mergeInputValues(InputFieldMapSource[] sources, boolean isTypeInputType = false) returns MergedResult|MergeError|MergeError[]|InternalError {
        map<InputSource[]> unionedInputs = {};
        foreach InputFieldMapSource [subgraph, arguments] in sources {
            foreach parser:__InputValue arg in arguments {
                if unionedInputs.hasKey(arg.name) {
                    unionedInputs.get(arg.name).push([subgraph, arg]);
                } else {
                    unionedInputs[arg.name] = [[subgraph, arg]];
                }
            }
        }

        Hint[] hints = [];
        MergeError[] errors = [];
        map<parser:__InputValue> mergedArguments = {};
        foreach [string, InputSource[]] [argName, argDefs] in unionedInputs.entries() {
            if argDefs.length() == sources.length() { // Arguments that are defined in all subgraphs
                DescriptionSource[] descriptionSources = [];
                DefaultValueSource[] defaultValueSources = [];
                TypeReferenceSource[] typeReferenceSources = [];
                foreach InputSource [subgraph, arg] in argDefs {
                    descriptionSources.push([
                        subgraph,
                        arg.description
                    ]);
                    defaultValueSources.push([
                        subgraph,
                        arg.defaultValue
                    ]);
                    typeReferenceSources.push([
                        subgraph,
                        arg.'type
                    ]);
                }

                TypeReferenceMergeResult|MergeError|InternalError inputTypeMergeResult = self.mergeTypeReferenceSet(typeReferenceSources, INPUT);
                if inputTypeMergeResult is MergeError {
                    // Handle errors
                    check appendErrors(errors, [inputTypeMergeResult], argName);
                    continue;
                }
                if inputTypeMergeResult is InternalError {
                    return inputTypeMergeResult;
                }
                parser:__Type mergedTypeReference = <parser:__Type>inputTypeMergeResult.result;
                appendHints(hints, inputTypeMergeResult.hints, argName);

                MergedResult|MergeError defaultValueMergeResult = check self.mergeDefaultValues(defaultValueSources);
                if defaultValueMergeResult is MergeError {
                    // Handle default value inconsistency
                    continue;
                }               
                appendHints(hints, defaultValueMergeResult.hints, argName);
                anydata? mergedDefaultValue = defaultValueMergeResult.result;

                MergedResult descriptionMergeResult = self.mergeDescription(descriptionSources);
                string? mergedDescription = <string?>descriptionMergeResult.result;
                appendHints(hints, descriptionMergeResult.hints, argName);

                parser:__InputValue mergedInputField = {
                    name: argName, 
                    'type: mergedTypeReference,
                    description: mergedDescription, 
                    defaultValue: mergedDefaultValue 
                };

                if isTypeInputType {
                    check self.applyJoinFieldDirectives(
                        mergedInputField.appliedDirectives, 
                        consistentSubgraphs = argDefs.'map(s => s[0]),
                        hasInconsistentFields = false,
                        outputTypeMismatches = inputTypeMergeResult.sources
                    );
                }

                mergedArguments[argName] = mergedInputField;
                
            } else {
                ConsistentInconsistenceSubgraphs subgraphs = self.getConsistentInconsistentSubgraphs(sources, argDefs);

                Hint hint = {
                    code: INCONSISTENT_ARGUMENT_PRESENCE,
                    location: [],
                    details: [{
                        value: argName,
                        consistentSubgraphs: subgraphs.consistent,
                        inconsistentSubgraphs: subgraphs.inconsistent
                    }]
                };
                hints.push(hint);

                boolean isRequiredTypeFound = argDefs.some(v => isTypeRequired(v[1].'type));
                if isRequiredTypeFound {
                    hint.code = REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH;
                    errors.push(error MergeError("Required argument is missing on some subgraph(s)", hint = hint));
                }
            }
        }

        return errors.length() > 0 ? errors : { result: mergedArguments, hints: hints };
    }

    isolated function mergeDefaultValues(DefaultValueSource[] sources) returns MergedResult|MergeError {
        map<DefaultValueSources> unionedDefaultValues = {};
        foreach DefaultValueSource [subgraph, value] in sources {
            string? valueString = value.toString();
            if valueString is string {
                if unionedDefaultValues.hasKey(valueString) {
                    unionedDefaultValues.get(valueString).subgraphs.push(subgraph);
                } else {
                    unionedDefaultValues[valueString] = { data: value, subgraphs: [ subgraph ] };
                }
            }
        }

        if unionedDefaultValues.length() == 1 {
            string defaultValueKey = unionedDefaultValues.keys()[0];
            return {
                result: unionedDefaultValues.get(defaultValueKey).data,
                hints: []
            };
        } else if unionedDefaultValues.length() == 2 && unionedDefaultValues.keys().indexOf("") !is () {
            string defaultValueKey = "";

            HintDetail[] details = [];
            foreach [string, DefaultValueSources] [key, value] in unionedDefaultValues.entries() {
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
                result: unionedDefaultValues.get(defaultValueKey).data,
                hints: [hint]
            };
        } else {
            // Handle default value inconsistency
            HintDetail[] details = [];
            foreach DefaultValueSources sourceGroup in unionedDefaultValues {
                details.push({
                    value: sourceGroup.data,
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

    isolated function mergeInterfaceImplements(parser:__Type 'type, Subgraph[] subgraphs) returns InternalError? {
        string? typeName = 'type.name;
        if typeName is () {
            return error InternalError("Invalid supergraph type");
        }

        foreach Subgraph subgraph in subgraphs {
            parser:__Type[]? interfacesResult = getTypeFromTypeMap(subgraph.schema, typeName).interfaces;
            if interfacesResult is () {
                return error InternalError("Invalid subgraph type");
            }

            foreach parser:__Type interfaceType in interfacesResult {
                parser:__Type supergraphInterfaceDef = check self.getTypeFromSupergraph(interfaceType.name);
                check implementInterface('type, supergraphInterfaceDef);
                check self.applyJoinImplementsDirective('type, subgraph, supergraphInterfaceDef);
            }
        }
    }

    isolated function mergeTypeReferenceSet(TypeReferenceSource[] sources, TypeReferenceType refType) returns TypeReferenceMergeResult|MergeError|InternalError {
        map<TypeReferenceSources> unionedReferences = {};
        foreach TypeReferenceSource [subgraph, typeReference] in sources {
            string key = check typeReferenceToString(typeReference);

            if !unionedReferences.hasKey(key) {
                unionedReferences[key] = { 
                    data: typeReference,
                    subgraphs: [ subgraph ]
                 };
            } else {
                unionedReferences.get(key).subgraphs.push(subgraph);
            }
        }

        Hint[] hints = [];
        HintCode code = refType == OUTPUT ? INCONSISTENT_BUT_COMPATIBLE_OUTPUT_TYPE : INCONSISTENT_BUT_COMPATIBLE_INPUT_TYPE;
        parser:__Type? mergedTypeReference = ();
        foreach TypeReferenceSources ref in unionedReferences {
            parser:__Type typeReference = ref.data;
            if mergedTypeReference is () {
                mergedTypeReference = typeReference;
            }
            
            if mergedTypeReference !is () {
                // mergedTypeReference = check mergerFn(mergedTypeReference, typeReference); 
                parser:__Type?|MergeError|InternalError result = refType == OUTPUT ? 
                                        self.getMergedOutputTypeReference(mergedTypeReference, typeReference) :
                                        self.getMergedInputTypeReference(mergedTypeReference, typeReference);
                if result is MergeError {
                    HintDetail[] details = [];
                    foreach [string, TypeReferenceSources] [typeName, typeSources] in unionedReferences.entries() {
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

        TypeReferenceSources[] typeRefs = [];
        if unionedReferences.length() > 1 {
            HintDetail[] details = [];
            foreach [string, Mismatch] [key, mismatch] in unionedReferences.entries() {
                details.push({
                    value: key,
                    consistentSubgraphs: mismatch.subgraphs,
                    inconsistentSubgraphs: []
                });
                typeRefs.push({
                    data: mismatch.data,
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
        
        // parser:__Type mergedTypeReference = typeReferences[0][1];
        // foreach [Subgraph, parser:__Type] [subgraph, typeReference] in typeReferences {
        //     mergedTypeReference = check self.getMergedTypeReference(typeReference, mergedTypeReference);
        // }
        // return mergedTypeReference;
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
        // Handle Type Reference mismatch
        // 'FIELD_TYPE_MISMATCH'
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
            // Handle Type Reference mismatch
            // 'FIELD_ARGUMENT_TYPE_MISMATCH', 'FIELD_TYPE_MISMATCH'
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

    isolated function applyJoinTypeDirectives() returns InternalError? {
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

                    EntityStatus entityStatus = self.isEntity(subgraphType);
                    if entityStatus.isEntity {
                        argMap[KEY_FIELD] = entityStatus.fields;
                        argMap[RESOLVABLE_FIELD] = entityStatus.isResolvable;
                    }

                    'type.appliedDirectives.push(
                        check self.getAppliedDirectiveFromName(JOIN_TYPE_DIR, argMap)
                    );
                }
            }
        }
    }

    isolated function applyJoinFieldDirectives(parser:__AppliedDirective[] appliedDirs, Subgraph[] consistentSubgraphs, 
                                      boolean hasInconsistentFields, TypeReferenceSources[] outputTypeMismatches) returns InternalError? {

        // Handle @override
        // Handle @external

        map<map<anydata>> joinFieldArgs = {};
        if hasInconsistentFields {
            foreach Subgraph subgraph in consistentSubgraphs {
                joinFieldArgs[subgraph.name][GRAPH_FIELD] = self.joinGraphMap.get(subgraph.name);
            }
        }

        foreach TypeReferenceSources ref in outputTypeMismatches {
            foreach Subgraph subgraph in ref.subgraphs {
                joinFieldArgs[subgraph.name][GRAPH_FIELD] = self.joinGraphMap.get(subgraph.name);
                joinFieldArgs[subgraph.name][TYPE_FIELD] = check typeReferenceToString(ref.data);
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

    isolated function applyJoinUnionMember(parser:__Type 'type, Subgraph subgraph, parser:__Type unionMember) returns InternalError? {
        'type.appliedDirectives.push(
            check self.getAppliedDirectiveFromName(
                JOIN_UNION_MEMBER_DIR,
                { 
                    [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name),
                    [UNION_MEMBER_FIELD]: unionMember.name
                }
            )
        );
    }

    isolated function applyJoinEnumDirective(parser:__EnumValue enumValue, Subgraph[] subgraphs) returns InternalError? {
        foreach Subgraph subgraph in subgraphs {
            enumValue.appliedDirectives.push(
                check self.getAppliedDirectiveFromName(
                    JOIN_ENUMVALUE_DIR,
                    { 
                        [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name)
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
            return getTypeFromTypeMap(self.supergraph.schema, name);
        } else {
            return error InternalError(string `Type '${name}' is not defined in the Supergraph`);
        }
    }

    isolated function isTypeOnSupergraph(string typeName) returns boolean {
        return isTypeOnTypeMap(self.supergraph.schema, typeName);
    }

    isolated function isEntity(parser:__Type 'type) returns EntityStatus {
        EntityStatus status = {
            isEntity: false,
            isResolvable: false,
            fields: ()
        };
        foreach parser:__AppliedDirective appliedDirective in 'type.appliedDirectives {
            if appliedDirective.definition.name == KEY_DIR {
                status.isEntity = true;

                anydata isResolvable = appliedDirective.args.get(RESOLVABLE_FIELD).value;
                if isResolvable is boolean {
                    status.isResolvable = isResolvable;
                } else {
                    // return error InternalError("Invalid resolvable value of @key directive");
                }

                anydata fields = appliedDirective.args.get(FIELDS_FIELD).value;
                if fields is string {
                    status.fields = fields;
                } else {
                    // return error InternalError("Invalid field set of @key directive");
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
        return self.isEntity('type).isEntity || self.isShareableOnType('type);
    }

    isolated function isShareableOnType(parser:__Type 'type) returns boolean {
        return isDirectiveApplied('type.appliedDirectives, SHAREABLE_DIR);
    }

    isolated function isShareableOnField(parser:__Field 'field) returns boolean {
        return isDirectiveApplied('field.appliedDirectives, SHAREABLE_DIR);
    }

    isolated function getConsistentInconsistentSubgraphs([Subgraph, anydata][] sources, [Subgraph, anydata][] defs) 
                                                                            returns ConsistentInconsistenceSubgraphs {
        Subgraph[] consistentSubgraphs = [];
        Subgraph[] inconsistentSubgraphs = [];
        foreach var [subgraph, _] in sources {
            boolean isConsistentSubgraph = false;
            foreach var [consistentSubgraph, _] in defs {
                if subgraph.name == consistentSubgraph.name {
                    isConsistentSubgraph = true;
                    break;
                }
            }
            
            if isConsistentSubgraph {
                consistentSubgraphs.push(subgraph);
            } else {
                inconsistentSubgraphs.push(subgraph);
            }
        }
        return {
            consistent: consistentSubgraphs,
            inconsistent: inconsistentSubgraphs
        };
    }

}