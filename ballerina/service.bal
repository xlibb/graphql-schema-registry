import ballerina/graphql;
import graphql_schema_registry.registry;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import graphql_schema_registry.merger;

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
        registry:CompositionResult|parser:SchemaError[]|merger:MergeError[] result = check self.registry.dryRun(schema);
        if result is registry:CompositionResult {
            return new CompositionResult(result);
        } else {
            check returnErrors(context, 'field, result);
            return;
        }
    }

    isolated resource function get subgraph(string name) returns Subgraph|error {
        return new Subgraph(check self.registry.getSubgraphByName(name));
    }

    isolated remote function publishSubgraph(graphql:Context context, graphql:Field 'field, SubgraphInput schema) returns CompositionResult|error? {
        registry:CompositionResult|parser:SchemaError[]|merger:MergeError[] result = check self.registry.publishSubgraph(schema);
        if result is registry:CompositionResult {
            return new CompositionResult(result);
        } else {
            check returnErrors(context, 'field, result);
            return;
        }
    }
}
