import ballerina/graphql;
import graphql_schema_registry.registry;

registry:Registry registry = check new();

service / on new graphql:Listener(9090) {

    resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check registry.getLatestSupergraph());
    }

    resource function get dryRun(registry:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check registry.dryRun(schema));
    }

    remote function publishSubgraph(registry:SubgraphSchema schema) returns Supergraph|error {
        return new Supergraph(check registry.publishSubgraph(schema));
    }
}
