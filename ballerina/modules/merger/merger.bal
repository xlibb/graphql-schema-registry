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
        map<parser:__Type> federation_types = check getFederationTypes(self.supergraph.schema.types);
        foreach [string,parser:__Type] [key, value] in federation_types.entries() {
            self.supergraph.schema.types[key] = value;
        }

        map<parser:__Directive> federation_directives = getFederationDirectives(self.supergraph.schema.types);
        foreach [string,parser:__Directive] [key, value] in federation_directives.entries() {
            self.supergraph.schema.directives[key] = value;
        }

        parser:__Type queryType = check self.getTypeFromSupergraph(QUERY);
        map<parser:__Field>? fields = queryType.fields;
        if fields is map<parser:__Field> {
            fields[_SERVICE_FIELD_TYPE] = {
                name: _SERVICE_FIELD_TYPE,
                args: {},
                'type: parser:wrapType(check self.getTypeFromSupergraph(_SERVICE_TYPE), parser:NON_NULL)
            };
        }

    }

    function populateFederationJoinGraphEnum() returns InternalError? {
        parser:__EnumValue[] enum_values = <parser:__EnumValue[]>self.supergraph.schema.types.get(JOIN_GRAPH_TYPE).enumValues;
        foreach Subgraph subgraph in self.subgraphs {

            parser:__EnumValue enum_value = {
                name: subgraph.name.toUpperAscii(),
                appliedDirectives: [ 
                                        check getAppliedDirectiveFromDirective(
                                                self.supergraph.schema.directives.get(JOIN_GRAPH_DIR),
                                                { "name": subgraph.name, "url": subgraph.url }
                                        ) 
                                    ]
            };

            enum_values.push(enum_value);
            self.joinGraphMap[subgraph.name] = enum_value;
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
                    self.supergraph.schema.types[key] = {
                        name: value.name,
                        kind: value.kind
                    };
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

                parser:__Directive supergraph_directive = {
                    name: value.name,
                    locations: check getDirectiveLocationsFromStrings(value.locations),
                    args: check self.getInputValueMap(value.args),
                    isRepeatable: value.isRepeatable
                };

                self.supergraph.schema.directives[key] = supergraph_directive;
            }
        }
    }

    function mergeUnionTypes() returns InternalError? {
        map<parser:__Type> supergraphUnionTypes = self.getTypeKeysOfKind(parser:UNION);
        foreach [string, parser:__Type] [typeName, mergedType] in supergraphUnionTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);

            // ---------- Merge Descriptions -----------
            [Subgraph, string?][] descriptions = [];
            foreach Subgraph subgraph in subgraphs {
                descriptions.push([
                    subgraph,
                    subgraph.schema.types.get(typeName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
            mergedType.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Possible Types -----------
            map<parser:__Type[]> possibleTypes = {};
            foreach Subgraph subgraph in subgraphs {
                parser:__Type[]? possibleTypesResult = subgraph.schema.types.get(typeName).possibleTypes;
                if possibleTypesResult is parser:__Type[] {
                    possibleTypes[subgraph.name] = possibleTypesResult;
                } else {
                    return error InternalError("Invalid union type");
                }

            }
            MergeResult possibleTypesMergeResult = check self.mergePossibleTypes(possibleTypes);
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
        map<parser:__Type> supergraphTypes = self.getTypeKeysOfKind(kind);
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
        map<parser:__Type> supergraphObjectTypes = self.getTypeKeysOfKind(parser:OBJECT);
        foreach [string, parser:__Type] [objectName, 'type] in supergraphObjectTypes.entries() {
            if isBuiltInType(objectName) || isSubgraphFederationType(objectName) {
                continue;
            }

            Subgraph[] subgraphs = self.getDefiningSubgraphs(objectName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            [Subgraph, string?][] descriptions = [];
            foreach Subgraph subgraph in subgraphs {
                descriptions.push([
                    subgraph,
                    subgraph.schema.types.get(objectName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
            'type.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Fields -----------
            [Subgraph, map<parser:__Field>][] fieldMaps = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__Field>? subgraphFields = subgraph.schema.types.get(objectName).fields;
                if subgraphFields is map<parser:__Field> {
                    fieldMaps.push([ subgraph, check self.getFilteredFields(objectName, subgraphFields) ]);
                }
            }
            map<parser:__Field> mergedFields = check self.mergeFields(fieldMaps, self.isTypeShareable('type));
            'type.fields = mergedFields;
        }
    }

    function mergeInterfaceTypes() returns MergeError|InternalError? {
        map<parser:__Type> supergraphInterfaceTypes = self.getTypeKeysOfKind(parser:INTERFACE);
        foreach [string, parser:__Type] [interfaceName, interface] in supergraphInterfaceTypes.entries() {

            Subgraph[] subgraphs = self.getDefiningSubgraphs(interfaceName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            [Subgraph, string?][] descriptions = [];
            foreach Subgraph subgraph in subgraphs {
                descriptions.push([
                    subgraph,
                    subgraph.schema.types.get(interfaceName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
            interface.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Fields -----------
            [Subgraph, map<parser:__Field>][] fieldMaps = [];
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
        map<parser:__Type> supergraphInputTypes = self.getTypeKeysOfKind(parser:INPUT_OBJECT);
        foreach [string, parser:__Type] [inputTypeName, 'type] in supergraphInputTypes.entries() {
            Subgraph[] subgraphs = self.getDefiningSubgraphs(inputTypeName);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            [Subgraph, string?][] descriptions = [];
            foreach Subgraph subgraph in subgraphs {
                descriptions.push([
                    subgraph,
                    subgraph.schema.types.get(inputTypeName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
            'type.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Input fields -----------
            [Subgraph, map<parser:__InputValue>][] inputFieldMaps = [];
            foreach Subgraph subgraph in subgraphs {
                map<parser:__InputValue>? subgraphFields = subgraph.schema.types.get(inputTypeName).inputFields;
                if subgraphFields is map<parser:__InputValue> {
                    inputFieldMaps.push([ subgraph, subgraphFields ]);
                }
            }
            map<parser:__InputValue> mergedFields = check self.mergeInputValues(inputFieldMaps);
            'type.inputFields = mergedFields;

        }
    }

    function mergeEnumTypes() returns InternalError? {
        map<parser:__Type> supergraphEnumTypes = self.getTypeKeysOfKind(parser:ENUM);
        foreach [string, parser:__Type] [typeName, mergedType] in supergraphEnumTypes.entries() {
            if isSubgraphFederationType(typeName) {
                continue;
            }
            Subgraph[] subgraphs = self.getDefiningSubgraphs(typeName);
            EnumTypeUsage usage = self.getEnumTypeUsage(mergedType);

            // ---------- Merge Descriptions -----------
            // [Subgraph, string?][] descriptions = subgraphs.map(s => [s, s.schema.types.get(typeName).description]);
            [Subgraph, string?][] descriptions = [];
            foreach Subgraph subgraph in subgraphs {
                descriptions.push([
                    subgraph,
                    subgraph.schema.types.get(typeName).description
                ]);
            }
            MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
            mergedType.description = <string?>descriptionMergeResult.result;
            if descriptionMergeResult.hints.length() > 0 {
                // Handle discription hints
            }

            // ---------- Merge Possible Types -----------
            map<parser:__EnumValue[]> allEnumValues = {};
            foreach Subgraph subgraph in subgraphs {
                parser:__EnumValue[]? enumValuesFromSubgraph = subgraph.schema.types.get(typeName).enumValues;
                if enumValuesFromSubgraph is parser:__EnumValue[] {
                    allEnumValues[subgraph.name] = enumValuesFromSubgraph;
                } else {
                    return error InternalError("Invalid enum type");
                }

                MergeResult? mergedEnumValuesResult = check self.mergeEnumValues(allEnumValues, usage);
                if mergedEnumValuesResult is MergeResult {
                    mergedType.enumValues = <parser:__EnumValue[]?>mergedEnumValuesResult.result;
                }
            }
        }
    }

    function mergeDescription([Subgraph, string?][] descriptions) returns MergeResult {
        if descriptions.length() == 0 {
            return {
                result: (),
                hints: []
            };
        }

        Mismatch[] preMerge = [];
        foreach int i in 0...descriptions.length()-1 {  // [Subgraph, string?] [iSubgraph, iDescription] = descriptions[i];
            string? iDescription = descriptions[i][1];
            if preMerge.some(t => t.data === iDescription) {
                continue;
            }

            Subgraph[] subgraphs = [];
            foreach int j in i...descriptions.length()-1 {
                [Subgraph, string?] [jSubgraph, jDescription] = descriptions[j];
                if iDescription === jDescription {
                    subgraphs.push(jSubgraph);
                }
            }

            preMerge.push({
                data: iDescription,
                subgraphs: subgraphs
            });
        }
        
        if preMerge.length() === 1 {
            return {
                result: <string?>preMerge[0].data,
                hints: []
            };
        } else {
            return {
                result: preMerge.filter(m => m.data !is ())[0].data,
                hints: preMerge
            };
        }
    }

    function mergeEnumValues(map<parser:__EnumValue[]> enumValues, EnumTypeUsage usage) returns MergeResult|InternalError? {
        // Map between Enum value's name and Subgraphs which define that enum value along with it's definition of the enum value
        map<[Subgraph, parser:__EnumValue][]> allEnumValues = {}; 
        foreach [string, parser:__EnumValue[]] [subgraphName, subgraphEnumVals] in enumValues.entries() {
            Subgraph subgraph = self.subgraphs.get(subgraphName);
            foreach parser:__EnumValue enumValue in subgraphEnumVals {
                if allEnumValues.hasKey(enumValue.name) {
                    allEnumValues.get(enumValue.name).push([subgraph, enumValue]);
                } else {
                    allEnumValues[enumValue.name] = [[subgraph, enumValue]];
                }
            }
        }

        // Same mapping as above, but filtered according to the merginig stratergy
        parser:__EnumValue[] mergedEnumValues = [];
        map<[Subgraph, parser:__EnumValue][]> filteredEnumValues = self.filterEnumValuesBasedOnUsage(allEnumValues, enumValues.length(), usage);

        foreach [string, [Subgraph, parser:__EnumValue][]] [enumValueName, filteredEnumValue] in filteredEnumValues.entries() {
            [Subgraph, string?][] descriptions = [];
            [Subgraph, [boolean, string?]][] deprecations = []; // Handle deprecations
            Subgraph[] definingSubgraphs = [];

            foreach [Subgraph, parser:__EnumValue] [subgraph, definition] in filteredEnumValue {
                definingSubgraphs.push(subgraph);
                descriptions.push([subgraph, definition.description]);
                deprecations.push([subgraph, [definition.isDeprecated, definition.deprecationReason]]);
            }

            MergeResult mergedDesc = self.mergeDescription(descriptions);
            // Handle deprecations

            parser:__EnumValue mergedEnumValue = {
                name: enumValueName,
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

    function filterEnumValuesBasedOnUsage(map<[Subgraph, parser:__EnumValue][]> allEnumValues, 
                                          int contributingSubgraphCount, EnumTypeUsage usage
                                        ) returns map<[Subgraph, parser:__EnumValue][]> {
        map<[Subgraph, parser:__EnumValue][]> filteredEnumValues = {};
        if usage.isUsedInInputs && usage.isUsedInOutputs {
            // Enum values must be exact
            boolean isConsistent = true;
            foreach [Subgraph, parser:__EnumValue][] definingSubgraphs in allEnumValues {
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
            foreach [string, [Subgraph, parser:__EnumValue][]] [enumValueName, definingSubgraphs] in allEnumValues.entries() {
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
            // Hint about not using this enum definition
        }

        return filteredEnumValues;
    }

    function mergeFields([Subgraph, map<parser:__Field>][] fields, boolean isTypeShareable = false) returns map<parser:__Field>|MergeError|InternalError {

        map<parser:__Field> mergedFields = {};
        // io:println(string `len = ${fields.'map(fe => string `${fe[1].'map(f => string `${f.name}:${f.appliedDirectives.toBalString()}`).toBalString()}`).toBalString()}`);
        // ----------------- Merge Fields Shallow (Take Union of the fields) ---------------
        foreach [Subgraph, map<parser:__Field>] [_, subgraphFields] in fields {
            foreach [string, parser:__Field] [fieldName, fieldValue] in subgraphFields.entries() {
                if !mergedFields.hasKey(fieldName) {
                    mergedFields[fieldName] = {
                        name: fieldName,
                        args: {},
                        'type: fieldValue.'type
                    };
                } else if !isTypeShareable && !self.isFieldShareable(fieldValue) {
                    // Handle 'INVALID_FIELD_SHARING'
                }
            }
        }

        // ----------------- Merge Fields deeply ---------------
        Mismatch[] mismatches = [];
        foreach [string, parser:__Field] [fieldName, 'field] in mergedFields.entries() {
            map<parser:__Field> consistentSubgraphs = {}; // Subgraphs which define the field
            Subgraph[] inconsistentSubgraphs = []; // Subgraphs which does not define the field

            [Subgraph, map<parser:__InputValue>][] inputValueMaps = [];
            [Subgraph, string?][] descriptions = [];
            [Subgraph, [boolean, string?]][] deprecations = []; // Handle deprecations
            [Subgraph, parser:__Type][] outputTypes = [];
            foreach [Subgraph, map<parser:__Field>] [subgraph, subgraphFields] in fields {
                if subgraphFields.hasKey(fieldName) {
                    parser:__Field mergingField = subgraphFields.get(fieldName);
                    consistentSubgraphs[subgraph.name] = mergingField;

                    inputValueMaps.push([
                        subgraph,
                        mergingField.args
                    ]);
                    descriptions.push([
                        subgraph,
                        mergingField.description
                    ]);
                    deprecations.push([
                        subgraph,
                        [ mergingField.isDeprecated, mergingField.deprecationReason ]
                    ]);
                    outputTypes.push([
                        subgraph,
                        mergingField.'type
                    ]);
                } else {
                    inconsistentSubgraphs.push(subgraph);
                }
            }

            mergedFields[fieldName].args = check self.mergeInputValues(inputValueMaps);

            MergeResult mergeDescriptionResult = self.mergeDescription(descriptions);
            mergedFields[fieldName].description = <string?>mergeDescriptionResult.result;
            if mergeDescriptionResult.hints.length() != 0 {
                // Handle inconsistent descriptions
            }

            MergeResult|MergeError outputTypeMergeResult = check self.mergeTypeReference(outputTypes, OUTPUT);
            Mismatch[] outputTypeMergeHints = [];
            if outputTypeMergeResult is MergeResult {
                mergedFields[fieldName].'type = <parser:__Type>outputTypeMergeResult.result;
                if outputTypeMergeResult.hints.length() > 0 {
                    outputTypeMergeHints = outputTypeMergeResult.hints;
                }
                // Handle inconsistent types hints
            }                

            check self.applyJoinFieldDirectives(
                'field, 
                consistentSubgraphs = consistentSubgraphs,
                hasInconsistentFields = inconsistentSubgraphs.length() > 0,
                outputTypeMismatches = outputTypeMergeHints
            );

            mismatches.push({ data: 'field, subgraphs: inconsistentSubgraphs });
        }

        return mergedFields;
        
    }

    function mergePossibleTypes(map<parser:__Type[]> types) returns MergeResult|InternalError {
        map<parser:__Type> mergedPossibleTypes = {};

        // Get union of possible types across subgraphs
        foreach parser:__Type[] possibleTypes in types {
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
            foreach [string, parser:__Type[]] [subgraphName, subgraphPossibleTypes] in types.entries() {
                boolean isTypePresent = false;
                foreach parser:__Type checkType in subgraphPossibleTypes {
                    if checkType.name == typeName {
                        isTypePresent = true;
                        break;
                    }
                }
                if !isTypePresent {
                    inconsistentSubgraphs.push(self.subgraphs.get(subgraphName));
                } else {
                    consistentSubgraphs.push(self.subgraphs.get(subgraphName));
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

    function mergeInputValues([Subgraph, map<parser:__InputValue>][] argumentMaps) returns map<parser:__InputValue>|MergeError|InternalError {
        map<parser:__InputValue> mergedArguments = {};
        map<Subgraph[]> preMerge = {}; // Map between an argument and the Subgraphs which define that argument

        // Get intersection of arguments between the subgraphs
        foreach [Subgraph, map<parser:__InputValue>] [subgraph, arguments] in argumentMaps {
            foreach string key in arguments.keys() {
                if preMerge.hasKey(key) {
                    preMerge.get(key).push(subgraph);
                } else {
                    preMerge[key] = [subgraph];
                }
            }
        }

        // Merge the intersected arguments
        foreach [string, Subgraph[]] [argName, subgraphs] in preMerge.entries() {

            if subgraphs.length() == argumentMaps.length() { // Arguments that are defined in all subgraphs
                [Subgraph, string?][] descriptions = [];
                [Subgraph, anydata?][] defaultValues = [];
                [Subgraph, parser:__Type][] types = [];
                foreach [Subgraph, map<parser:__InputValue>] [subgraph, argumentMap] in argumentMaps {
                    descriptions.push([
                        subgraph,
                        argumentMap.get(argName).description
                    ]);
                    defaultValues.push([
                        subgraph,
                        argumentMap.get(argName).defaultValue
                    ]);
                    types.push([
                        subgraph,
                        argumentMap.get(argName).'type
                    ]);
                }

                MergeResult|MergeError inputTypeMergeResult = check self.mergeTypeReference(types, INPUT);
                if inputTypeMergeResult is MergeResult && inputTypeMergeResult.hints.length() > 0 {
                    // Handle type reference hints
                } else if inputTypeMergeResult is MergeError {
                    // Handle Type reference merge error
                    continue;
                }                

                MergeResult|MergeError defaultValueMergeResult = check self.mergeDefaultValues(defaultValues);
                if defaultValueMergeResult is MergeError {
                    // Handle default value inconsistency
                    continue;
                }               

                MergeResult descriptionMergeResult = self.mergeDescription(descriptions);
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

    function mergeTypeReference([Subgraph, parser:__Type][] typeReferences, TypeReferenceType refType) returns MergeResult|MergeError|InternalError {
        map<Mismatch> groupedTypeReferences = {};
        foreach [Subgraph, parser:__Type] [subgraph, typeReference] in typeReferences {
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

    function mergeDefaultValues([Subgraph, anydata?][] defaultValues) returns MergeResult|MergeError {
        // map<[anydata, Subgraph[]]> intersected = {};
        map<Mismatch> intersected = {};
        foreach [Subgraph, anydata?] [subgraph, value] in defaultValues {
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

    function applyJoinFieldDirectives(parser:__Field 'field, map<parser:__Field> consistentSubgraphs, 
                                      boolean hasInconsistentFields, Mismatch[] outputTypeMismatches) returns InternalError? {

        // Handle @override
        // Handle @external

        map<map<anydata>> join__fieldArgs = {};
        if hasInconsistentFields {
            foreach string subgraphName in consistentSubgraphs.keys() {
                join__fieldArgs[subgraphName][GRAPH_FIELD] = self.joinGraphMap.get(subgraphName);
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

    // Filter out the Subgraphs which defines the given typeName
    function getDefiningSubgraphs(string typeName) returns Subgraph[] {
        Subgraph[] subgraphs = [];
        foreach Subgraph subgraph in self.subgraphs {
            if subgraph.schema.types.hasKey(typeName) {
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
                parser:__Type|InternalError|MergeError mergedOutputTypeRef = self.getMergedOutputTypeReference(enumType, 'field.'type);
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

            parser:__Type|InternalError|MergeError mergedInputTypeRef = self.getMergedInputTypeReference(enumType, arg.'type);
            isUsedInInputs = mergedInputTypeRef is parser:__Type;
        }
        return isUsedInInputs;
    }

    function getTypeKeysOfKind(parser:__TypeKind kind) returns map<parser:__Type> {
        return self.supergraph.schema.types.filter(t => t.kind === kind);
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

    function getSupergraphDirectiveDefinition(parser:__Directive sub_dir_def) returns parser:__Directive {
        return self.supergraph.schema.directives.get(sub_dir_def.name);
    }

    function getTypeFromSupergraph(string? name) returns parser:__Type|InternalError {
        if name is () {
            return error InternalError(string `Type name cannot be null`);
        }
        if self.isTypeOnSupergraph(name) {
            return self.supergraph.schema.types.get(name);
        } else {
            return error InternalError(string `Type '${name}' is not defined in the Supergraph`);
        }
    }

    function isTypeOnSupergraph(string typeName) returns boolean {
        return self.supergraph.schema.types.hasKey(typeName);
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
            return self.supergraph.schema.directives.get(name);
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
        return self.supergraph.schema.directives.hasKey(directiveName);
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