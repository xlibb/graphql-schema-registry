import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;

public class Registry {

    private Persist persist;

    public function init() returns error? {
        self.persist = check new("datasource");
    }

    public function publishSubgraph(SubgraphSchema subgraphSchema) returns SupergraphSchema|error {
        SupergraphSchema composeResult = check self.composeSupergraph(subgraphSchema);
        check self.registerSupergraph(composeResult);
        return composeResult;
    }

    public function dryRun(SubgraphSchema subgraphSchema) returns SupergraphSchema|error {
        SupergraphSchema composeResult = check self.composeSupergraph(subgraphSchema);
        return composeResult;
    }

    public function getLatestSupergraph() returns SupergraphSchema|error {
        SupergraphSchema? snapshot = check self.persist.getLatestSchemas();
        if snapshot is () {
            return error RegistryError("No supergraph schemas found");
        }
        return snapshot;
    }

    public function getSubgraphByName(string name) returns SubgraphSchema|error {
        SupergraphSchema snapshot = check self.getLatestSupergraph();
        if !snapshot.subgraphs.hasKey(name) {
            return error RegistryError(string `No subgraph found with the given name '${name}'`);
        }
        return snapshot.subgraphs.get(name);
    }

    function composeSupergraph(SubgraphSchema subgraphSchema) returns SupergraphSchema|error {
        map<SubgraphSchema> subgraphs = check self.getSubgraphSdls();
        subgraphs[subgraphSchema.name] = createSubgraphSdl(subgraphSchema.name, subgraphSchema.url, subgraphSchema.sdl);
        merger:Supergraph composedSupergraph = check self.mergeSubgraphs(subgraphs);
        string supergraphSdl = check self.exportSchema(composedSupergraph.schema);
        return {
            schema: supergraphSdl,
            subgraphs: subgraphs
        };
    }

    function registerSupergraph(SupergraphSchema records) returns error? {
        check self.persist.register({
            subgraphs: records.subgraphs,
            schema: records.schema
        });
    }

    function getSubgraphSdls() returns map<SubgraphSchema>|error {
        SupergraphSchema?|error latestSchemas = self.persist.getLatestSchemas();
        if latestSchemas is SupergraphSchema {
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