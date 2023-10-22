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
        self.addFederationDefinitions();
        check self.populateFederationJoinGraphEnum();
        check self.addTypesShallow();
        check self.addDirectives();
        return self.supergraph;
    }

    function addFederationDefinitions() {
        map<parser:__Type> federation_types = getFederationTypes();
        foreach [string,parser:__Type] [key, value] in federation_types.entries() {
            self.supergraph.schema.types[key] = value;
        }

        map<parser:__Directive> federation_directives = getFederationDirectives(self.supergraph.schema.types);
        foreach [string,parser:__Directive] [key, value] in federation_directives.entries() {
            self.supergraph.schema.directives[key] = value;
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
                    if (self.getTypeFromSupergraph(key).kind !== value.kind) {
                        // Handle Kind
                    }
                } else {
                    self.supergraph.schema.types[key] = {
                        name: value.name,
                        kind: value.kind
                    };
                }
                
                // Add join__type directive
                parser:__Type 'type = self.getTypeFromSupergraph(key);
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
                    args: self.getInputValueMap(value.args),
                    isRepeatable: value.isRepeatable
                };

                self.supergraph.schema.directives[key] = supergraph_directive;
            }
        }
    }

    function getSupergraphDirectiveDefinition(parser:__Directive sub_dir_def) returns parser:__Directive {
        return self.supergraph.schema.directives.get(sub_dir_def.name);
    }

    function getTypeFromSupergraph(string name) returns parser:__Type {
        return self.supergraph.schema.types.get(name);
    };

    function isTypeOnSupergraph(string typeName) returns boolean {
        return self.supergraph.schema.types.hasKey(typeName);
    }

    function isDirectiveOnSupergraph(string directiveName) returns boolean {
        return self.supergraph.schema.directives.hasKey(directiveName);
    }

    function getInputValueMap(map<parser:__InputValue> sub_map) returns map<parser:__InputValue> {
        map<parser:__InputValue> inputValueMap = {};
        foreach [string, parser:__InputValue] [key, value] in sub_map.entries() {
            inputValueMap[key] = {
                name: value.name,
                description: value.description,
                'type: self.getInputTypeFromSupergraph(value.'type),
                appliedDirectives: [],
                defaultValue: value.defaultValue
            };
        }
        return inputValueMap;
    }

    function getInputTypeFromSupergraph(parser:__Type 'type) returns parser:__Type {
        if 'type.kind is parser:WRAPPING_TYPE {
            return parser:wrapType(
                self.getInputTypeFromSupergraph(<parser:__Type>'type.ofType), 
                <parser:WRAPPING_TYPE>'type.kind
            );
        } else {
            return self.getTypeFromSupergraph(<string>'type.name);
        }
    }
}