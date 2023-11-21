import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;

public class Registry {

    private datasource:Datasource datasource;

    public function init(datasource:Datasource datasource) returns error? {
        self.datasource = datasource;
    }

    public function publishSubgraph(datasource:SubgraphSchema subgraphSchema) returns datasource:SupergraphSchema|error {
        datasource:SupergraphSchema composeResult = check self.composeSupergraph(subgraphSchema);
        composeResult = check self.registerSupergraph(composeResult);
        return composeResult;
    }

    public function dryRun(datasource:SubgraphSchema subgraphSchema) returns datasource:SupergraphSchema|error {
        datasource:SupergraphSchema composeResult = check self.composeSupergraph(subgraphSchema);
        composeResult.version = check self.datasource.getLatestVersion() ?: datasource:createInitialVersion();
        return composeResult;
    }

    public function getLatestSupergraph() returns datasource:SupergraphSchema|error {
        datasource:SupergraphSchema? snapshot = check self.datasource.getLatestSchemas();
        if snapshot is () {
            return error RegistryError("No supergraph schemas found");
        }
        return snapshot;
    }

    public function getSubgraphByName(string name) returns datasource:SubgraphSchema|error {
        datasource:SupergraphSchema snapshot = check self.getLatestSupergraph();
        if !snapshot.subgraphs.hasKey(name) {
            return error RegistryError(string `No subgraph found with the given name '${name}'`);
        }
        return snapshot.subgraphs.get(name);
    }

    function composeSupergraph(datasource:SubgraphSchema subgraphSchema) returns datasource:SupergraphSchema|error {
        map<datasource:SubgraphSchema> subgraphs = check self.getSubgraphSdls();
        subgraphs[subgraphSchema.name] = datasource:createSubgraphSdl(subgraphSchema.name, subgraphSchema.url, subgraphSchema.sdl);
        merger:Supergraph composedSupergraph = check self.mergeSubgraphs(subgraphs);
        string supergraphSdl = check self.exportSchema(composedSupergraph.schema);
        return {
            schema: supergraphSdl,
            subgraphs: subgraphs
        };
    }

    function registerSupergraph(datasource:SupergraphSchema records) returns datasource:SupergraphSchema|error {
        return self.datasource.register({
            subgraphs: records.subgraphs,
            schema: records.schema
        });
    }

    function getSubgraphSdls() returns map<datasource:SubgraphSchema>|error {
        datasource:SupergraphSchema?|error latestSchemas = self.datasource.getLatestSchemas();
        if latestSchemas is datasource:SupergraphSchema {
            return latestSchemas.subgraphs;
        }
        if latestSchemas is () {
            return {};
        }
        return latestSchemas;
    }

    function mergeSubgraphs(map<datasource:SubgraphSchema> subgraphSdls) returns merger:Supergraph|error {
        merger:Subgraph[] subgraphs = subgraphSdls.toArray().'map(s => check datasource:createSubgraph(s));
        return check (check new merger:Merger(subgraphs)).merge();
    }

    function exportSchema(parser:__Schema schema) returns string|error {
        return check (new exporter:Exporter(schema)).export();
    }
}