import graphql_schema_registry.datasource;

public distinct service class Subgraph {
    private final readonly & datasource:SubgraphSchema schemaRecord;

    function init(datasource:SubgraphSchema schema) {
        self.schemaRecord = schema.cloneReadOnly();
    }

    resource function get name() returns string {
        return self.schemaRecord.name;
    }

    resource function get id() returns string {
        return self.schemaRecord.id;
    }

    resource function get schema() returns string {
        return self.schemaRecord.sdl;
    }
}

public distinct service class Supergraph {
    private final readonly & datasource:SupergraphSchema schemaRecord;

    function init(datasource:SupergraphSchema schemaRecord) {
        self.schemaRecord = schemaRecord.cloneReadOnly();
    }

    resource function get subgraphs() returns Subgraph[] {
        return self.schemaRecord.subgraphs.toArray().map(s => new Subgraph(s));
    }

    resource function get schema() returns string {
        return self.schemaRecord.schema;
    }

    resource function get version() returns string|error {
        datasource:Version? & readonly version = self.schemaRecord.version;
        if version is () {
            return error("Invalid version");
        }
        return datasource:getVersionAsString(version);
    }

    resource function get apiSchema() returns string {
        return self.schemaRecord.apiSchema;
    }

}