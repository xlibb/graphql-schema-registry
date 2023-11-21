import ballerina/graphql;
import graphql_schema_registry.registry;

service / on new graphql:Listener(9090) {

    private registry:Registry registry;

    public function init() returns error? {
        registry:Persist persistency = check new registry:Persist("datasource");
        self.registry = check new registry:Registry(persistency);
    }

    resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check self.registry.getLatestSupergraph());
    }

    resource function get dryRun(registry:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check self.registry.dryRun(schema));
    }

    resource function get subgraph(string name) returns Subgraph|error {
        return new Subgraph(check self.registry.getSubgraphByName(name));
    }

    remote function publishSubgraph(registry:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check self.registry.publishSubgraph(schema));
    }
}
