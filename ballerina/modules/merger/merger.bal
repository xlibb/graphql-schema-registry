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

    function populateFederationJoinGraphEnum() returns error? {
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

    function addTypesShallow() returns error? {
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
                
                // Add join__type directive
                parser:__Type 'type = check self.getTypeFromSupergraph(key);
                'type.appliedDirectives.push(
                    check getAppliedDirectiveFromDirective(
                        self.supergraph.schema.directives.get(JOIN_TYPE_DIR),
                        { "graph": self.joinGraphMap.get(subgraph.name) }
                    )
                );
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
            return error InternalError(string `Given type '${name}' is not defined in the Supergraph`);
        }
    }

    function isTypeOnSupergraph(string typeName) returns boolean {
        return self.supergraph.schema.types.hasKey(typeName);
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

    function populateObjectTypes() returns InternalError? {
        map<parser:__Type> supergraphObjectTypes = self.getTypeKeysOfKind(parser:OBJECT);
        foreach [string, parser:__Type] [key, supergraphObject] in supergraphObjectTypes.entries() {

            supergraphObject.interfaces = [];
            supergraphObject.fields = {};

            foreach Subgraph subgraph in self.subgraphs {
                if subgraph.schema.types.hasKey(key) {
                    parser:__Type subgraphObject = subgraph.schema.types.get(key);

                    // Handle description mimatch, fields mismatch
                    supergraphObject.description = subgraphObject.description;
                    supergraphObject.interfaces = check self.getInterfacesArray(subgraphObject.interfaces);

                    map<parser:__Field>? subgraphFields = subgraphObject.fields;
                    if subgraphFields !is () {
                        supergraphObject.fields = check self.getFieldMap(subgraphFields);
                    }
                }
            }
        }
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

    function getInterfacesArray(parser:__Type[]? subgraphInterfaces) returns parser:__Type[]|InternalError {
        if subgraphInterfaces is () {
            return error InternalError("Interfaces cannot be null");
        }

        parser:__Type[] supergraphInterfaces = [];
        foreach parser:__Type subgraphInterface in subgraphInterfaces {
            supergraphInterfaces.push(
                check self.getTypeFromSupergraph(subgraphInterface.name)
            );
        }

        return supergraphInterfaces;
    }
}