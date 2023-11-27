import graphql_schema_registry.registry;

public type SubgraphInput record {|
    *registry:Subgraph;
|};

public distinct service class Subgraph {
    private final readonly & registry:Subgraph schemaRecord;

    function init(registry:Subgraph schema) {
        self.schemaRecord = schema.cloneReadOnly();
    }

    resource function get name() returns string {
        return self.schemaRecord.name;
    }

    resource function get schema() returns string {
        return self.schemaRecord.schema;
    }
}

public distinct service class Supergraph {
    private final readonly & registry:Supergraph schemaRecord;

    function init(registry:Supergraph schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.map(s => new Subgraph(s));
    }

    resource function get schema() returns string {
        return self.schemaRecord.schema;
    }

    resource function get version() returns string|error {
        return self.schemaRecord.version;
    }

    resource function get apiSchema() returns string {
        return self.schemaRecord.apiSchema;
    }

    resource function get hints() returns string[] {
        return self.schemaRecord.hints;
    }

}