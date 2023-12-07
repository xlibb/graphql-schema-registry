import ballerina/graphql;
import graphql_schema_registry.registry;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import graphql_schema_registry.merger;
import graphql_schema_registry.differ;

isolated service / on new graphql:Listener(9090) {

    private final registry:Registry registry;
    
    public function init() returns error? {
        datasource:Datasource datasource = check new FileDatasource("datasource");
        // datasource:Datasource datasource = new InMemoryDatasource();
        self.registry = new(datasource);
    }

    isolated resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check self.registry.getLatestSupergraph());
    }

    isolated resource function get supergraphVersions() returns string[]|error {
        return check self.registry.getVersions();
    }

    isolated resource function get dryRun(graphql:Context context, graphql:Field 'field, SubgraphInput schema, boolean isForced = false) returns CompositionResult|error? {
        registry:CompositionResult|parser:SchemaError[]|merger:MergeError[]|registry:OperationCheckError[] result = check self.registry.dryRun(schema, isForced);
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

    isolated resource function get diff(graphql:Context context, graphql:Field 'field, string newVersion, string oldVersion) returns differ:SchemaDiff[]|error {
        return check self.registry.getDiff(newVersion, oldVersion);
    }

    isolated remote function publishSubgraph(graphql:Context context, graphql:Field 'field, SubgraphInput schema, boolean isForced = false) returns CompositionResult|error? {
        registry:CompositionResult|parser:SchemaError[]|merger:MergeError[]|registry:OperationCheckError[] result = check self.registry.publishSubgraph(schema, isForced);
        if result is registry:CompositionResult {
            return new CompositionResult(result);
        } else {
            check returnErrors(context, 'field, result);
            return;
        }
    }
}
