import graphql_schema_registry.registry;

public type SubgraphInput record {|
    *registry:Subgraph;
|};

public distinct service isolated class Subgraph {
    private final readonly & registry:Subgraph schemaRecord;

    isolated function init(registry:Subgraph schema) {
        self.schemaRecord = schema.cloneReadOnly();
    }

    isolated resource function get name() returns string {
        return self.schemaRecord.name;
    }

    isolated resource function get schema() returns string {
        return self.schemaRecord.schema;
    }
}

public distinct service isolated class Supergraph {
    private final readonly & registry:Supergraph schemaRecord;

    isolated function init(registry:Supergraph schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    isolated resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.map(s => new Subgraph(s));
    }

    isolated resource function get schema() returns string {
        return self.schemaRecord.schema;
    }

    isolated resource function get version() returns string|error {
        return self.schemaRecord.version;
    }

    isolated resource function get apiSchema() returns string {
        return self.schemaRecord.apiSchema;
    }

    isolated resource function get hints() returns string[] {
        return self.schemaRecord.hints;
    }

}