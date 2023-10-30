import graphql_schema_registry.parser;

public class Merger {

    private Supergraph supergraph;
    private Subgraph[] subgraphs;
    private map<parser:__EnumValue> joinGraphMap;

    public function init(Subgraph[] subgraphs) {
        self.subgraphs = subgraphs.clone();
        self.joinGraphMap = {};
        self.supergraph = {
            schema: createSchema(),
            subgraphs: self.subgraphs
        };
    }

    public function merge() returns Supergraph|error {
        check self.addFederationDefinitions();
        check self.populateFederationJoinGraphEnum();
        check self.addTypesShallow();
        check self.addDirectives();
        check self.populateObjectTypes();
        check self.populateInterfaceTypes();
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
            fields["_service"] = {
                name: "_service",
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

    function populateUnionTypes() {
        map<parser:__Type> supergraphUnionTypes = self.getTypeKeysOfKind(parser:UNION);
        foreach [string, parser:__Type] [key, supergraphUnion] in supergraphUnionTypes.entries() {
            foreach Subgraph subgraph in self.subgraphs {
                if subgraph.schema.types.hasKey(key) {
                    parser:__Type subgraphUnion = subgraph.schema.types.get(key);

                    // Handle description mimatch, possibleTypes mismatch
                    supergraphUnion.description = subgraphUnion.description;
                    supergraphUnion.possibleTypes = subgraphUnion.possibleTypes;
                }
            }
        }
    }

    function populateObjectTypes() returns MergeError|InternalError? {
        map<parser:__Type> supergraphObjectTypes = self.getTypeKeysOfKind(parser:OBJECT);
        foreach [string, parser:__Type] [objectName, 'type] in supergraphObjectTypes.entries() {
            if isBuiltInType(objectName) || isSubgraphFederationType(objectName) {
                continue;
            }

            // Using filter here causes a Compiler error (not compilation error)
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
                    fieldMaps.push([ subgraph, subgraphFields ]);
                }
            }
            map<parser:__Field> mergedFields = check self.mergeFields(fieldMaps);
            'type.fields = mergedFields;

            // ---------- Merge Implements -------
            'type.interfaces = [];
            check self.mergeInterfaceImplements('type, subgraphs);
        }
    }

    function populateInterfaceTypes() returns MergeError|InternalError? {
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

            // ---------- Merge Implements -------
            interface.interfaces = [];
            check self.mergeInterfaceImplements(interface, subgraphs);

            interface.possibleTypes = [];
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

    function mergeFields([Subgraph, map<parser:__Field>][] fields) returns map<parser:__Field>|MergeError|InternalError {

        map<parser:__Field> mergedFields = {};

        // ----------------- Merge Fields Shallow (Take Union of the fields) ---------------
        foreach [Subgraph, map<parser:__Field>] [_, subgraphFields] in fields {
            foreach [string, parser:__Field] [fieldName, fieldValue] in subgraphFields.entries() {
                if !mergedFields.hasKey(fieldName) {
                    mergedFields[fieldName] = {
                        name: fieldName,
                        args: {},
                        'type: fieldValue.'type
                    };
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

            MergeResult|MergeError outputTypeMergeResult = check self.mergeTypeReference(outputTypes);
            Mismatch[] outputTypeMergeHints = [];
            if outputTypeMergeResult is MergeResult {
                mergedFields[fieldName].'type = <parser:__Type>outputTypeMergeResult.result;
                if outputTypeMergeResult.hints.length() > 0 {
                    outputTypeMergeHints = outputTypeMergeResult.hints;
                }
                // Handle inconsistent types hints
            } else if outputTypeMergeResult is MergeError {
                // Handle Type reference merge error
            }                

            check self.applyJoinFieldDirectives(
                'field, 
                consistentSubgraphs = consistentSubgraphs,
                inconsistentSubgraphs = inconsistentSubgraphs,
                outputTypeMismatches = outputTypeMergeHints
            );

            mismatches.push({ data: 'field, subgraphs: inconsistentSubgraphs });
        }

        return mergedFields;
        
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

                MergeResult|MergeError inputTypeMergeResult = check self.mergeTypeReference(types);
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
            }
        }


        return mergedArguments;
    }

    function mergeTypeReference([Subgraph, parser:__Type][] typeReferences) returns MergeResult|MergeError|InternalError {
        map<Mismatch> intersectedTypeReferences = {};
        foreach [Subgraph, parser:__Type] [subgraph, typeReference] in typeReferences {
            string key = check typeReferenceToString(typeReference);

            if !intersectedTypeReferences.hasKey(key) {
                intersectedTypeReferences[key] = { 
                    data: typeReference,
                    subgraphs: [ subgraph ]
                 };
            } else {
                intersectedTypeReferences.get(key).subgraphs.push(subgraph);
            }
        }

        parser:__Type? mergedTypeReference = ();
        foreach Mismatch intersectedTypeReference in intersectedTypeReferences {
            parser:__Type typeReference = <parser:__Type>intersectedTypeReference.data;
            if mergedTypeReference is () {
                mergedTypeReference = typeReference;
            }
            
            if mergedTypeReference !is () {
                mergedTypeReference = check self.getMergedTypeReference(mergedTypeReference, typeReference);
            }
        }

        Mismatch[] mismatches = [];
        if intersectedTypeReferences.length() > 1 {
            foreach [string, Mismatch] [key, mismatch] in intersectedTypeReferences.entries() {
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

    function getMergedTypeReference(parser:__Type typeA, parser:__Type typeB) returns parser:__Type|InternalError|MergeError {
        parser:__Type? typeAWrappedType = typeA.ofType;
        parser:__Type? typeBWrappedType = typeB.ofType;


        // typeA == typeB check might have to be done with only the name, and not the whole type because the type might not have been constructed completely
        if typeAWrappedType is () && typeBWrappedType is () && typeA == typeB {
            return check self.getTypeFromSupergraph(typeA.name);
        } else if typeBWrappedType !is () && typeBWrappedType == typeA && typeB.kind == parser:NON_NULL {
            return parser:wrapType(
                check self.getMergedTypeReference(typeA, typeBWrappedType), 
                parser:NON_NULL
            );
        } else if typeAWrappedType !is () && typeA.kind == parser:NON_NULL && typeAWrappedType == typeB {
            return parser:wrapType(
                check self.getMergedTypeReference(typeAWrappedType, typeB),
                parser:NON_NULL
            );
        } else if typeAWrappedType !is () && typeBWrappedType !is () && typeA.kind == typeB.kind {
            return parser:wrapType(
                check self.getMergedTypeReference(typeAWrappedType, typeBWrappedType),
                <parser:WRAPPING_TYPE>typeA.kind
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
                    'type.appliedDirectives.push(
                        check self.getAppliedDirectiveFromName(JOIN_TYPE_DIR, {
                            [GRAPH_FIELD]: self.joinGraphMap.get(subgraph.name) 
                        })
                    );
                }
            }
        }
    }

    function applyJoinFieldDirectives(parser:__Field 'field, map<parser:__Field> consistentSubgraphs, 
                                      Subgraph[] inconsistentSubgraphs, Mismatch[] outputTypeMismatches) returns InternalError? {

        // Handle @override
        // Handle @external

        map<map<anydata>> join__fieldArgs = {};
        if inconsistentSubgraphs.length() > 0 {
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
                    "interface": interfaceType.name
                }
            )
        );
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

    function getTypeKeysOfKind(parser:__TypeKind kind) returns map<parser:__Type> {
        return self.supergraph.schema.types.filter(t => t.kind === kind);
    }

    function getFieldMap(map<parser:__Field> subgraphFields) returns map<parser:__Field>|InternalError {
        map<parser:__Field> supergraphFields = {};
        foreach [string, parser:__Field] [key, subgraphField] in subgraphFields.entries() {
            if !isFederationFieldType(key) {
                supergraphFields[key] = {
                    args: check self.getInputValueMap(subgraphField.args), 
                    name: subgraphField.name, 
                    'type: check self.getInputTypeFromSupergraph(subgraphField.'type)
                };
            }
        }
        return supergraphFields;
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
}