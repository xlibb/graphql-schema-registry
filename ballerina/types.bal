import graphql_schema_registry.registry;
public distinct service class Subgraph {
    private final readonly & registry:SubgraphSchema schemaRecord;

    function init(registry:SubgraphSchema schema) {
        self.schemaRecord = schema.cloneReadOnly();
    }

    resource function get name() returns string {
        return self.schemaRecord.name;
    }

    resource function get id() returns string {
        return "<not implemented>";
    }

    resource function get schema() returns string {
        return self.schemaRecord.sdl;
    }
}

public distinct service class Supergraph {
    private final readonly & registry:SupergraphSchema schemaRecord;

    function init(registry:SupergraphSchema schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.toArray().map(s => new Subgraph(s));
    }

    resource function get schema() returns string {
        return self.schemaRecord.schema;
    }

}