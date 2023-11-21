import ballerina/graphql;
import graphql_schema_registry.registry;
import graphql_schema_registry.datasource;

service / on new graphql:Listener(9090) {

    private registry:Registry registry;

    public function init() returns error? {
        datasource:Datasource datasource = check new FileDatasource("datasource");
        self.registry = check new registry:Registry(datasource);
    }

    resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check self.registry.getLatestSupergraph());
    }

    resource function get dryRun(datasource:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check self.registry.dryRun(schema));
    }

    resource function get subgraph(string name) returns Subgraph|error {
        return new Subgraph(check self.registry.getSubgraphByName(name));
    }

    remote function publishSubgraph(datasource:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check self.registry.publishSubgraph(schema));
    }
}
