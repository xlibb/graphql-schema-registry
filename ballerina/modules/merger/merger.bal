import graphql_schema_registry.parser;

public function merge(Subgraph[] subgraphs) returns parser:__Schema|error {
    parser:__Schema supergraph_schema = createSchema();
    addFederationTypes(supergraph_schema, subgraphs);
    check addSubgraphsTypesShallow(supergraph_schema, subgraphs);
    return supergraph_schema;
}

function addSubgraphsTypesShallow(parser:__Schema supergraph_schema, Subgraph[] subgraphs) returns error? {
    foreach Subgraph subgraph in subgraphs {
        check addSubgraphTypesShallow(supergraph_schema, subgraph);
    }
}

function addSubgraphTypesShallow(parser:__Schema supergraph_schema, Subgraph subgraph) returns error? {
    foreach [string, parser:__Type] [key, value] in subgraph.schema.types.entries() {
        if FEDERATION_SUBGRAPH_IGNORE_TYPES.indexOf(key) is () {
            if (supergraph_schema.types.hasKey(key)) {
                // Handle Description            
                // Handle Kind
            } else {
                supergraph_schema.types[key] = {
                    name: value.name,
                    description: value.description,
                    kind: value.kind,
                    appliedDirectives: []
                };
            }
            
            parser:__Type 'type = supergraph_schema.types.get(key);
            
            // Add join__type directive
            'type.appliedDirectives.push(
                check getAppliedDirectiveFromDirective(
                    supergraph_schema.directives.get(JOIN_TYPE_DIR),
                    { "graph": check getJoinGraphEnumValue(supergraph_schema, subgraph) }
                )
            );

        }
    }
}

// Get the Enum value from the 'join__Graph' enum for the given Subgraph
function getJoinGraphEnumValue(parser:__Schema schema, Subgraph subgraph) returns parser:__EnumValue|error {
    parser:__EnumValue[]? enum_values = schema.types.get(JOIN_GRAPH_TYPE).enumValues;
    if enum_values !is () {
        return enum_values.filter(v => v.name == subgraph.name.toUpperAscii())[0];
    } else {
        return error(string `'${JOIN_GRAPH_TYPE}' types' 'enumValues' cannot be nil.`);
    }
}

function createSchema() returns parser:__Schema {
    [map<parser:__Type>, map<parser:__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get("Query")
    };
}