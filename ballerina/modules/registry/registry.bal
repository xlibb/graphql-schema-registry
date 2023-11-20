import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;

public class Registry {

    private Persist persist;

    public function init() returns error? {
        self.persist = check new("datasource");
    }

    public function publishSubgraph(SubgraphSchema subgraphSchema) returns SchemaSnapshot|error {
        SchemaSnapshot composeResult = check self.composeSupergraph(subgraphSchema);
        check self.registerSupergraph(composeResult);
        return composeResult;
    }

    public function dryRun(SubgraphSchema subgraphSchema) returns SchemaSnapshot|error {
        SchemaSnapshot composeResult = check self.composeSupergraph(subgraphSchema);
        return composeResult;
    }

    public function getLatestSupergraph() returns SchemaSnapshot|error {
        SchemaSnapshot? snapshot = check self.persist.getLatestSchemas();
        if snapshot is () {
            return error RegistryError("No supergraph schemas found");
        }
        return snapshot;
    }

    function composeSupergraph(SubgraphSchema subgraphSchema) returns SchemaSnapshot|error {
        map<SubgraphSchema> subgraphs = check self.getSubgraphSdls();
        subgraphs[subgraphSchema.name] = createSubgraphSdl(subgraphSchema.name, subgraphSchema.url, subgraphSchema.sdl);
        merger:Supergraph composedSupergraph = check self.mergeSubgraphs(subgraphs);
        string supergraphSdl = check self.exportSchema(composedSupergraph.schema);
        return {
            supergraph: supergraphSdl,
            subgraphs: subgraphs
        };
    }

    function registerSupergraph(SchemaSnapshot records) returns error? {
        check self.persist.register({
            subgraphs: records.subgraphs,
            supergraph: records.supergraph
        });
    }

    function getSubgraphSdls() returns map<SubgraphSchema>|error {
        SchemaSnapshot?|error latestSchemas = self.persist.getLatestSchemas();
        if latestSchemas is SchemaSnapshot {
            return latestSchemas.subgraphs;
        }
        if latestSchemas is () {
            return {};
        }
        return latestSchemas;
    }

    function mergeSubgraphs(map<SubgraphSchema> subgraphSdls) returns merger:Supergraph|error {
        merger:Subgraph[] subgraphs = subgraphSdls.toArray().'map(s => check createSubgraph(s));
        return check (check new merger:Merger(subgraphs)).merge();
    }

    function exportSchema(parser:__Schema schema) returns string|error {
        return check (new exporter:Exporter(schema)).export();
    }
}