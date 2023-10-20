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
                if FEDERATION_SUBGRAPH_IGNORE_TYPES.indexOf(key) !is () {
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

    function getSupergraphDirectiveDefinition(parser:__Directive sub_dir_def) returns parser:__Directive {
        return self.supergraph.schema.directives.get(sub_dir_def.name);
    }

    function getTypeFromSupergraph(string name) returns parser:__Type {
        return self.supergraph.schema.types.get(name);
    };

    function isTypeOnSupergraph(string typeName) returns boolean {
        return self.supergraph.schema.types.hasKey(typeName);
    }
}