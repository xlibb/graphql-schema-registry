import graphql_schema_registry.parser;

public function merge(Subgraph[] subgraphs) returns parser:__Schema {
    parser:__Schema supergraph_schema = createSchema();
    addFederationTypes(supergraph_schema, subgraphs);
    addSubgraphsTypesShallow(supergraph_schema, subgraphs);
    return supergraph_schema;
}

function addSubgraphsTypesShallow(parser:__Schema supergraph_schema, Subgraph[] subgraphs) {
    foreach Subgraph subgraph in subgraphs {
        addSubgraphTypesShallow(supergraph_schema, subgraph);
    }
}

function addSubgraphTypesShallow(parser:__Schema supergraph_schema, Subgraph subgraph) {
    // foreach [string, parser:__Type] [key, value] in subgraph.schema.types.entries() {
    //     if (supergraph_schema.types.hasKey(key)) {
            // Handle Description            
            // Move directive names to one place
            // supergraph_schema.types.get("join__Graph").enumValues
    //     } else {

    //     }
    // }
}

public function createSubgraph(string name, string url, parser:__Schema schema) returns Subgraph {
    return {
        name,
        url,
        schema
    };
}

function createSchema() returns parser:__Schema {
    [map<parser:__Type>, map<parser:__Directive>] [types, directives] = getBuiltInDefinitions();
    return {
        types,
        directives,
        queryType: types.get("Query")
    };
}