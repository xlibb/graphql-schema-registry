import graphql_schema_registry.parser;

public class Merger {

    private Supergraph supergraph;
    private map<Subgraph> subgraphs;
    private map<parser:__EnumValue> joinGraphMap;

    public function init(Subgraph[] subgraphs) {
        self.subgraphs = {};
        foreach Subgraph subgraph in subgraphs {
            self.subgraphs[subgraph.name] = subgraph;
        }
        self.joinGraphMap = {};
        self.supergraph = {
            schema: createSchema(),
            subgraphs: self.subgraphs.toArray()
        };
    }

    public function merge() returns Supergraph|error {
        check self.addFederationDefinitions();
        check self.populateFederationJoinGraphEnum();
        check self.addTypesShallow();
        check self.addDirectives();
        check self.mergeUnionTypes();
        check self.mergeImplementsRelationship();
        check self.mergeObjectTypes();
        check self.mergeInterfaceTypes();
        check self.mergeInputTypes();
        check self.mergeEnumTypes();
        check self.applyJoinTypeDirectives();
        return self.supergraph;
    }

    function addFederationDefinitions() returns InternalError? {
        map<parser:__Type> federationTypes = check getFederationTypes(self.supergraph.schema.types);
        foreach parser:__Type 'type in federationTypes {
            check self.addTypeToSupergraph('type);
        }

        map<parser:__Directive> federationDirs = getFederationDirectives(self.supergraph.schema.types);
        foreach parser:__Directive directive in federationDirs {
            self.addDirectiveToSupergraph(directive);
        }

        parser:__Type queryType = check self.getTypeFromSupergraph(QUERY);
        map<parser:__Field>? fields = queryType.fields;
        if fields is map<parser:__Field> {
            parser:__Type _serviceType = parser:wrapType(
                                            check self.getTypeFromSupergraph(_SERVICE_TYPE), 
                                            parser:NON_NULL
                                        );

            fields[_SERVICE_FIELD_TYPE] = {
                name: _SERVICE_FIELD_TYPE,
                'type: _serviceType,
                args: {}
            };
        }

    }

    function populateFederationJoinGraphEnum() returns InternalError? {
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

    function addTypesShallow() returns InternalError? {
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Type] [key, value] in subgraph.schema.types.entries() {
                if isSubgraphFederationType(key) {
                    continue;
                }

                if self.isTypeOnSupergraph(key) {
                    if ((check self.getTypeFromSupergraph(key)).kind !== value.kind) {
                        // Handle Kind
                    }
                } else {
                    check self.addTypeToSupergraph({
                        name: value.name,
                        kind: value.kind
                    });
                }
                
            }
        }
    }

    function addDirectives() returns InternalError? {
        foreach Subgraph subgraph in self.subgraphs {
            foreach [string, parser:__Directive] [key, value] in subgraph.schema.directives.entries() {
                if isBuiltInDirective(key) || !isExecutableDirective(value) || isSubgraphFederationDirective(key) {
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

    function mergeUnionTypes() returns InternalError? {
        map<parser:__Type> supergraphUnionTypes = self.getSupergraphTypesOfKind(parser:UNION);
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
            MergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Possible Types -----------
            PossibleTypesSource[] possibleTypesSources = [];
            foreach Subgraph subgraph in subgraphs {
                parser:__Type[]? possibleTypesResult = getTypeFromTypeMap(subgraph.schema, typeName).possibleTypes;
                if possibleTypesResult is parser:__Type[] {
                    possibleTypesSources.push([
                        subgraph,
                        possibleTypesResult
                    ]);
                } else {
                    return error InternalError("Invalid union type");
                }

            }
            MergeResult possibleTypesMergeResult = check self.mergePossibleTypes(possibleTypesSources);
            mergedType.possibleTypes = <parser:__Type[]?>possibleTypesMergeResult.result;

            foreach Mismatch mismatch in possibleTypesMergeResult.hints {
                foreach Subgraph consistentSubgraph in mismatch.subgraphs {
                    check self.applyJoinUnionMember(
                        mergedType,
                        consistentSubgraph,
                        <parser:__Type>mismatch.data
                    );
                }                
            }
        }
    }

    function mergeImplementsRelationship() returns InternalError? {
        check self.mergeImplementsOf(parser:OBJECT);
        check self.mergeImplementsOf(parser:INTERFACE);
    }

    function mergeImplementsOf(parser:__TypeKind kind) returns InternalError? {
        map<parser:__Type> supergraphTypes = self.getSupergraphTypesOfKind(kind);
        foreach [string, parser:__Type] [typeName, 'type] in supergraphTypes.entries() {
            if isBuiltInType(typeName) || isSubgraphFederationType(typeName) {
                continue;
            }

            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            'type.interfaces = [];
            check self.mergeInterfaceImplements('type, subgraphs);
        }
    }

    function mergeObjectTypes() returns MergeError|InternalError? {
        map<parser:__Type> supergraphObjectTypes = self.getSupergraphTypesOfKind(parser:OBJECT);
        foreach [string, parser:__Type] [objectName, 'type] in supergraphObjectTypes.entries() {
            if isBuiltInType(objectName) || isSubgraphFederationType(objectName) {
                continue;
            }

            Subgraph[] subgraphs = self.getDefiningSubgraphs(objectName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptionSources = subgraphs.map(s => [s, s.schema.types.get(objectName).description]);
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, objectName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            'type.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Fields -----------
            FieldMapSource[] fieldMapSources = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__Field>? subgraphFields = subgraph.schema.types.get(objectName).fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMapSources.push([
                        subgraph, 
                        check self.getFilteredFields(objectName, subgraphFields) 
                    ]);
                }
            }
            map<parser:__Field> mergedFields = check self.mergeFields(fieldMapSources, self.isTypeShareable('type));
            'type.fields = mergedFields;
        }
    }

    function mergeInterfaceTypes() returns MergeError|InternalError? {
        map<parser:__Type> supergraphInterfaceTypes = self.getSupergraphTypesOfKind(parser:INTERFACE);
        foreach [string, parser:__Type] [interfaceName, interface] in supergraphInterfaceTypes.entries() {

            Subgraph[] subgraphs = self.getDefiningSubgraphs(interfaceName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            DescriptionSource[] descriptionSourcecs = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSourcecs.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, interfaceName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptionSourcecs);
            interface.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Fields -----------
           FieldMapSource[] fieldMaps = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__Field>? subgraphFields = subgraph.schema.types.get(interfaceName).fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMaps.push([ subgraph, subgraphFields ]);
                }
            }
            map<parser:__Field> mergedFields = check self.mergeFields(fieldMaps);
            interface.fields = mergedFields;

            interface.possibleTypes = [];
        }
    }

    function mergeInputTypes() returns MergeError|InternalError? {
        map<parser:__Type> supergraphInputTypes = self.getSupergraphTypesOfKind(parser:INPUT_OBJECT);
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
            MergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            'type.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Input fields -----------
            InputFieldMapSource[] inputFieldSources = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__InputValue>? subgraphFields = getTypeFromTypeMap(subgraph.schema, inputTypeName).inputFields;
                if subgraphFields is map<parser:__InputValue> {
                    inputFieldSources.push([ subgraph, subgraphFields ]);
                }
            }
            map<parser:__InputValue> mergedFields = check self.mergeInputValues(inputFieldSources);
            'type.inputFields = mergedFields;

        }
    }

    function mergeEnumTypes() returns InternalError? {
        map<parser:__Type> supergraphEnumTypes = self.getSupergraphTypesOfKind(parser:ENUM);
        foreach [string, parser:__Type] [typeName, mergedType] in supergraphEnumTypes.entries() {
            if isSubgraphFederationType(typeName) {
                continue;
            }
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);
            EnumTypeUsage usage = self.getEnumTypeUsage(mergedType);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            DescriptionSource[] descriptionSources = [];
            foreach Subgraph subgraph in subgraphs {
                descriptionSources.push([
                    subgraph,
                    getTypeFromTypeMap(subgraph.schema, typeName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
            mergedType.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

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
    }

    function mergeDescription(DescriptionSource[] sources) returns MergeResult {
        SourceGroup[] sourceGroups = []; // Map cannot be used here because descriptions are Nullable
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

        return sourceGroups.length() === 1 ? {
            result: <string?>sourceGroups[0].data,
            hints: []
        } : {
            result: sourceGroups.filter(m => m.data !is ())[0].data,
            hints: sourceGroups
        };
    }

    function mergeEnumValues(EnumValueSetSource[] sources, EnumTypeUsage usage) returns MergeResult|InternalError? {
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

            MergeResult mergedDesc = self.mergeDescription(descriptionSources);
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

    function filterEnumValuesBasedOnUsage(map<EnumValueSource[]> allEnumValues, 
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

    function mergeFields(FieldMapSource[] sources, boolean isTypeShareable = false) returns map<parser:__Field>|MergeError|InternalError {

        // Get union of all the fields
        map<FieldSource[]> unionedFields = {};
        foreach FieldMapSource [subgraph, subgraphFields] in sources {
            foreach [string, parser:__Field] [fieldName, fieldValue] in subgraphFields.entries() {
                if !unionedFields.hasKey(fieldName) {
                    unionedFields[fieldName] = [[subgraph, fieldValue]];
                } else { // Handle Shareable here (!isTypeShareable && !self.isFieldShareable(fieldValue))
                    unionedFields.get(fieldName).push([subgraph, fieldValue]);
                }
            }
        }

        // Merge all the unioned fields
        map<parser:__Field> mergedFields = {};
        foreach [string, FieldSource[]] [fieldName, fieldSources] in unionedFields.entries() {
            InputFieldMapSource[] inputFieldSources = [];
            DescriptionSource[] descriptionSources = [];
            DeprecationSource[] deprecationSources = []; // Handle deprecations
            TypeReferenceSource[] outputTypes = [];

            foreach FieldSource [subgraph, mergingField] in fieldSources {
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

            map<parser:__InputValue> mergedArgs = check self.mergeInputValues(inputFieldSources);

            MergeResult mergeDescriptionResult = self.mergeDescription(descriptionSources);
            string? mergedDescription = <string?>mergeDescriptionResult.result;
            if mergeDescriptionResult.hints.length() != 0 {
                // Handle inconsistent descriptions
            }

            MergeResult|MergeError outputTypeMergeResult = check self.mergeTypeReferences(outputTypes, OUTPUT);
            Mismatch[] outputTypeMergeHints = [];
            if outputTypeMergeResult is MergeError {
                return error MergeError("");
            }                
            if outputTypeMergeResult.hints.length() > 0 {
                // Handle inconsistent types hints
                outputTypeMergeHints = outputTypeMergeResult.hints;
            }
            parser:__Type mergedOutputType = <parser:__Type>outputTypeMergeResult.result;

            parser:__Field mergedField = {
                name: fieldName,
                args: mergedArgs,
                description: mergedDescription,
                'type: mergedOutputType
            };

            check self.applyJoinFieldDirectives(
                mergedField, 
                consistentSubgraphs = fieldSources.'map(s => s[0]),
                hasInconsistentFields = unionedFields.get(fieldName).length() != sources.length(),
                outputTypeMismatches = outputTypeMergeHints
            );

            mergedFields[mergedField.name] = mergedField;

            // mismatches.push({ data: mergedFields, subgraphs: inconsistentSubgraphs });
        }

        return mergedFields;
        
    }

    function mergePossibleTypes(PossibleTypesSource[] sources) returns MergeResult|InternalError {
        map<parser:__Type> mergedPossibleTypes = {};

        // Get union of possible types across subgraphs
        foreach PossibleTypesSource [_, possibleTypes] in sources {
            foreach parser:__Type possibleType in possibleTypes {
                string? possibleTypeName = possibleType.name;
                if possibleTypeName !is () {
                    mergedPossibleTypes[possibleTypeName] = check self.getTypeFromSupergraph(possibleTypeName);
                }
            }
        }

        // Find inconsistencies across subgraphs
        Mismatch[] mismatches = [];
        foreach [string, parser:__Type] [typeName, 'type] in mergedPossibleTypes.entries() {
            Subgraph[] inconsistentSubgraphs = [];
            Subgraph[] consistentSubgraphs = [];
            foreach PossibleTypesSource [subgraph, subgraphPossibleTypes] in sources {
                boolean isTypePresent = false;
                foreach parser:__Type checkType in subgraphPossibleTypes {
                    if checkType.name == typeName {
                        isTypePresent = true;
                        break;
                    }
                }
                if !isTypePresent {
                    inconsistentSubgraphs.push(subgraph);
                } else {
                    consistentSubgraphs.push(subgraph);
                }
            }
            mismatches.push({
                data: 'type,
                subgraphs: consistentSubgraphs
            });
        }

        return {
            result: mergedPossibleTypes.toArray(),
            hints: mismatches
        };
    }

    function mergeInputValues(InputFieldMapSource[] sources) returns map<parser:__InputValue>|MergeError|InternalError {
        map<Subgraph[]> preMerge = {}; // Map between an argument and the Subgraphs which define that argument
        foreach InputFieldMapSource [subgraph, arguments] in sources {
            foreach string key in arguments.keys() {
                if preMerge.hasKey(key) {
                    preMerge.get(key).push(subgraph);
                } else {
                    preMerge[key] = [subgraph];
                }
            }
        }

        map<parser:__InputValue> mergedArguments = {};
        foreach [string, Subgraph[]] [argName, subgraphs] in preMerge.entries() { // Get intersection of all arguments
            if subgraphs.length() == sources.length() { // Arguments that are defined in all subgraphs
                DescriptionSource[] descriptionSources = [];
                DefaultValueSource[] defaultValueSources = [];
                TypeReferenceSource[] typeReferenceSources = [];
                foreach InputFieldMapSource [subgraph, argumentMap] in sources {
                    descriptionSources.push([
                        subgraph,
                        argumentMap.get(argName).description
                    ]);
                    defaultValueSources.push([
                        subgraph,
                        argumentMap.get(argName).defaultValue
                    ]);
                    typeReferenceSources.push([
                        subgraph,
                        argumentMap.get(argName).'type
                    ]);
                }

                MergeResult|MergeError inputTypeMergeResult = check self.mergeTypeReferences(typeReferenceSources, INPUT);
                if inputTypeMergeResult is MergeResult && inputTypeMergeResult.hints.length() > 0 {
                    // Handle type reference hints
                } else if inputTypeMergeResult is MergeError {
                    // Handle Type reference merge error
                    continue;
                }                

                MergeResult|MergeError defaultValueMergeResult = check self.mergeDefaultValues(defaultValueSources);
                if defaultValueMergeResult is MergeError {
                    // Handle default value inconsistency
                    continue;
                }               

                MergeResult descriptionMergeResult = self.mergeDescription(descriptionSources);
                if descriptionMergeResult.hints.length() > 0 {
                    // Handle description merge hints
                }

                if inputTypeMergeResult is MergeResult {
                    mergedArguments[argName] = {
                        name: argName, 
                        'type: <parser:__Type>inputTypeMergeResult.result, // Merge the type (for now assuming that all the types are same across all the subgraphs)
                        description: <string?>descriptionMergeResult.result, // Merge the descriptions (for now assuming that all the descriptions are same across all the subgraphs)
                        defaultValue: <anydata>defaultValueMergeResult.result // Merge the default values (for now assuming that all the default values are same across all the subgraphs)
                    };
                }
                
            } else {
                // Handle 'INCONSISTENT_ARGUMENT_PRESENCE'
                // https://www.apollographql.com/docs/federation/federated-types/sharing-types/#arguments
            }
        }


        return mergedArguments;
    }

    function mergeTypeReferences(TypeReferenceSource[] sources, TypeReferenceType refType) returns MergeResult|MergeError|InternalError {
        map<Mismatch> groupedTypeReferences = {};
        foreach TypeReferenceSource [subgraph, typeReference] in sources {
            string key = check typeReferenceToString(typeReference);

            if !groupedTypeReferences.hasKey(key) {
                groupedTypeReferences[key] = { 
                    data: typeReference,
                    subgraphs: [ subgraph ]
                 };
            } else {
                groupedTypeReferences.get(key).subgraphs.push(subgraph);
            }
        }

        function (parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError mergerFn;
        if refType == OUTPUT {
            mergerFn = self.getMergedOutputTypeReference;
        } else if refType == INPUT {
            mergerFn = self.getMergedInputTypeReference;
        }

        parser:__Type? mergedTypeReference = ();
        foreach Mismatch intersectedTypeReference in groupedTypeReferences {
            parser:__Type typeReference = <parser:__Type>intersectedTypeReference.data;
            if mergedTypeReference is () {
                mergedTypeReference = typeReference;
            }
            
            if mergedTypeReference !is () {
                mergedTypeReference = check mergerFn(mergedTypeReference, typeReference); 
            }
        }

        Mismatch[] mismatches = [];
        if groupedTypeReferences.length() > 1 {
            foreach [string, Mismatch] [key, mismatch] in groupedTypeReferences.entries() {
                mismatches.push({
                    data: key,
                    subgraphs: mismatch.subgraphs
                });
            }
        }
        
        return {
            result: mergedTypeReference,
            hints: mismatches
        };
        
        // parser:__Type mergedTypeReference = typeReferences[0][1];
        // foreach [Subgraph, parser:__Type] [subgraph, typeReference] in typeReferences {
        //     mergedTypeReference = check self.getMergedTypeReference(typeReference, mergedTypeReference);
        // }
        // return mergedTypeReference;
    }

    function mergeInterfaceImplements(parser:__Type 'type, Subgraph[] subgraphs) returns InternalError? {
        string? typeName = 'type.name;

        if typeName is () {
            return error InternalError("Invalid supergraph interface type");
        }

        // Populate interfaces
        foreach Subgraph subgraph in subgraphs {
            parser:__Type[]? interfacesResult = subgraph.schema.types.get(typeName).interfaces;
            if interfacesResult is () {
                return error InternalError("Invalid subgraph interface type");
            }

            foreach parser:__Type interfaceType in interfacesResult {
                parser:__Type supergraphInterfaceDef = check self.getTypeFromSupergraph(interfaceType.name);
                check implementInterface('type, supergraphInterfaceDef);
                check self.applyJoinImplementsDirective('type, subgraph, supergraphInterfaceDef);
            }
        }
    }

    function getMergedOutputTypeReference(parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError {
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
        // 'ARGUMENT_TYPE_MISMATCH', 'FIELD_TYPE_MISMATCH'
        // 'INCONSISTENT_BUT_COMPATIBLE_ARGUMENT_TYPE', 'INCONSISTENT_BUT_COMPATIBLE_FIELD_TYPE'
        return error MergeError(string `Reference type mismatch`);
        
    }

    function getMergedInputTypeReference(parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError {
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
            // 'ARGUMENT_TYPE_MISMATCH', 'FIELD_TYPE_MISMATCH'
            // 'INCONSISTENT_BUT_COMPATIBLE_ARGUMENT_TYPE', 'INCONSISTENT_BUT_COMPATIBLE_FIELD_TYPE'
            return error MergeError(string `Reference type mismatch`);
        }
    }

    function mergeDefaultValues(DefaultValueSource[] sources) returns MergeResult|MergeError {
        // map<[anydata, Subgraph[]]> intersected = {};
        map<Mismatch> intersected = {};
        foreach DefaultValueSource [subgraph, value] in sources {
            string? valueString = value.toString();
            if valueString is string {
                if intersected.hasKey(valueString) {
                    intersected.get(valueString).subgraphs.push(subgraph);
                } else {
                    intersected[valueString] = { data: value, subgraphs: [ subgraph ] };
                }
            }
        }

        if intersected.length() == 1 {
            string defaultValueKey = intersected.keys()[0];
            return {
                result: intersected.get(defaultValueKey).data,
                hints: []
            };
        } else {
            // Handle default value inconsistency
            return error MergeError("Default type mismatch");
        }
    
    }

    function addTypeToSupergraph(parser:__Type 'type) returns InternalError? {
        check addTypeDefinition(self.supergraph.schema, 'type);
    }

    function addDirectiveToSupergraph(parser:__Directive directive) {
        addDirectiveDefinition(self.supergraph.schema, directive);
    }

    function applyJoinTypeDirectives() returns InternalError? {
        foreach [string, parser:__Type] [key, 'type] in self.supergraph.schema.types.entries() {
            if isSubgraphFederationType(key) || isBuiltInType(key) {
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

    function applyJoinFieldDirectives(parser:__Field 'field, Subgraph[] consistentSubgraphs, 
                                      boolean hasInconsistentFields, Mismatch[] outputTypeMismatches) returns InternalError? {

        // Handle @override
        // Handle @external

        map<map<anydata>> join__fieldArgs = {};
        if hasInconsistentFields {
            foreach Subgraph subgraph in consistentSubgraphs {
                join__fieldArgs[subgraph.name][GRAPH_FIELD] = self.joinGraphMap.get(subgraph.name);
            }
        }

        foreach Mismatch mismatch in outputTypeMismatches {
            foreach Subgraph subgraph in mismatch.subgraphs {
                join__fieldArgs[subgraph.name][GRAPH_FIELD] = self.joinGraphMap.get(subgraph.name);
                join__fieldArgs[subgraph.name][TYPE_FIELD] = mismatch.data;
            }
        }

        foreach map<anydata> args in join__fieldArgs {
            'field.appliedDirectives.push(check self.getAppliedDirectiveFromName(JOIN_FIELD_DIR, args));
        }
    }

    function applyJoinImplementsDirective(parser:__Type 'type, Subgraph subgraph, parser:__Type interfaceType) returns InternalError? {
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

    function applyJoinUnionMember(parser:__Type 'type, Subgraph subgraph, parser:__Type unionMember) returns InternalError? {
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

    function applyJoinEnumDirective(parser:__EnumValue enumValue, Subgraph[] subgraphs) returns InternalError? {
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

    function applyJoinGraph(parser:__EnumValue enumValue, string name, string url) returns InternalError? {
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
    function getDefiningSubgraphs(string typeName) returns Subgraph[] {
        Subgraph[] subgraphs = [];
        foreach Subgraph subgraph in self.subgraphs {
            if isTypeOnTypeMap(subgraph.schema, typeName) {
                subgraphs.push(subgraph);
            }
        }

        return subgraphs;
    }

    function getEnumTypeUsage(parser:__Type enumType) returns EnumTypeUsage {
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

    function getEnumTypeUsageInFields(parser:__Type enumType, map<parser:__Field> fields) returns EnumTypeUsage {
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

    function getEnumTypeUsageInArgs(parser:__Type enumType, map<parser:__InputValue> args) returns boolean {
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

    function getSupergraphTypesOfKind(parser:__TypeKind kind) returns map<parser:__Type> {
        return getTypesOfKind(self.supergraph.schema, kind);
    }

    function getFilteredFields(string typeName, map<parser:__Field> subgraphFields) returns map<parser:__Field>|InternalError {
        map<parser:__Field> filteredFields = {};
        foreach [string, parser:__Field] [key, subgraphField] in subgraphFields.entries() {
            if !(typeName == QUERY && isFederationFieldType(key)) {
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

    function getTypeFromSupergraph(string? name) returns parser:__Type|InternalError {
        if name is () {
            return error InternalError(string `Type name cannot be null`);
        }
        if self.isTypeOnSupergraph(name) {
            return getTypeFromTypeMap(self.supergraph.schema, name);
        } else {
            return error InternalError(string `Type '${name}' is not defined in the Supergraph`);
        }
    }

    function isTypeOnSupergraph(string typeName) returns boolean {
        return isTypeOnTypeMap(self.supergraph.schema, typeName);
    }

    function isEntity(parser:__Type 'type) returns EntityStatus {
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

    function getDirectiveFromSupergraph(string name) returns parser:__Directive|InternalError {
        if self.isDirectiveOnSupergraph(name) {
            return getDirectiveFromDirectiveMap(self.supergraph.schema, name);
        } else {
            return error InternalError(string `Directive '${name}' is not defined in the Supergraph`);
        }
    }

    function getAppliedDirectiveFromName(string name, map<anydata> args) returns parser:__AppliedDirective|InternalError {
        return check getAppliedDirectiveFromDirective(
            check self.getDirectiveFromSupergraph(name), args
        );
    }

    function isDirectiveOnSupergraph(string directiveName) returns boolean {
        return isDirectiveOnDirectiveMap(self.supergraph.schema, directiveName);
    }

    function getInputValueMap(map<parser:__InputValue> sub_map) returns map<parser:__InputValue>|InternalError {
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

    function getInputTypeFromSupergraph(parser:__Type 'type) returns parser:__Type|InternalError {
        if 'type.kind is parser:WRAPPING_TYPE {
            return parser:wrapType(
                check self.getInputTypeFromSupergraph(<parser:__Type>'type.ofType), 
                <parser:WRAPPING_TYPE>'type.kind
            );
        } else {
            return check self.getTypeFromSupergraph(<string>'type.name);
        }
    }

    function isTypeShareable(parser:__Type 'type) returns boolean {
        return self.isDirectiveApplied('type.appliedDirectives, SHAREABLE_DIR);
    }

    function isFieldShareable(parser:__Field 'field) returns boolean {
        return self.isDirectiveApplied('field.appliedDirectives, SHAREABLE_DIR);
    }

    function isDirectiveApplied(parser:__AppliedDirective[] appliedDirectives, string directiveName) returns boolean {
        boolean isApplied = false;
        foreach parser:__AppliedDirective dir in appliedDirectives {
            if dir.definition.name == directiveName {
                isApplied = true;
                break;
            }
        }
        return isApplied;
    }

}