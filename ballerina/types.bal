import graphql_schema_registry.registry;
public distinct service class Subgraph {
    private final readonly & registry:SubgraphSchema schema;

    function init(registry:SubgraphSchema schema) {
        self.schema = schema.cloneReadOnly();
    }

    resource function get name() returns string {
        return self.schema.name;
    }

    resource function get id() returns string {
        return "<not implemented>";
    }

    resource function get schema() returns string {
        return self.schema.sdl;
    }
}

public distinct service class Supergraph {
    private final readonly & registry:SchemaSnapshot schema;

    function init(registry:SchemaSnapshot schema) {
        self.schema = schema.cloneReadOnly();
    }

    resource function get subgraphs() returns Subgraph[] {
        return self.schema.subgraphs.toArray().map(s => new Subgraph(s));
    }

    resource function get schema() returns string {
        return self.schema.supergraph;
    }

}