import ballerina/graphql;
import graphql_schema_registry.registry;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;

isolated service / on new graphql:Listener(9090) {

    private final registry:Registry registry;
    

    public function init() returns error? {
        // datasource:Datasource datasource = check new FileDatasource("datasource");
        datasource:Datasource datasource = new InMemoryDatasource();
        self.registry = new(datasource);
    }

    isolated resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check self.registry.getLatestSupergraph());
    }

    isolated resource function get dryRun(graphql:Context context, graphql:Field 'field, SubgraphInput schema) returns CompositionResult|error? {
        registry:CompositionResult|parser:SchemaError[] result = check self.registry.dryRun(schema);
        if result is parser:SchemaError[] {
            returnErrors(context, 'field, "Schema Errors", result);
            return;
        }
        return new CompositionResult(result);
    }

    isolated resource function get subgraph(string name) returns Subgraph|error {
        return new Subgraph(check self.registry.getSubgraphByName(name));
    }

    isolated remote function publishSubgraph(graphql:Context context, graphql:Field 'field, SubgraphInput schema) returns CompositionResult|error? {
        registry:CompositionResult|parser:SchemaError[] publishSubgraphResult = check self.registry.publishSubgraph(schema);
        if publishSubgraphResult is parser:SchemaError[] {
            returnErrors(context, 'field, "Schema Errors", publishSubgraphResult);
            return;
        }
        return new CompositionResult(publishSubgraphResult);
    }
}
