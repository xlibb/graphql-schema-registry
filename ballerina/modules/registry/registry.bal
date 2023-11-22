import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;

public class Registry {

    private datasource:Datasource datasource;

    public function init(datasource:Datasource datasource) returns error? {
        self.datasource = datasource;
    }

    public function publishSubgraph(datasource:InputSubgraph subgraphSchema) returns datasource:SupergraphSchema|error {
        datasource:SupergraphSchema supergraph = check self.composeSupergraph(subgraphSchema);
        supergraph.subgraphs[subgraphSchema.name] = check self.datasource.registerSubgraph(subgraphSchema);
        return check self.datasource.registerSupergraph(supergraph);
    }

    public function dryRun(datasource:InputSubgraph subgraphSchema) returns datasource:SupergraphSchema|error {
        return check self.composeSupergraph(subgraphSchema);
    }

    public function composeSupergraph(datasource:InputSubgraph subgraphSchema) returns datasource:SupergraphSchema|error {
        map<datasource:SubgraphSchema> subgraphs = check self.getSubgraphSdls();
        merger:Subgraph[] filteredSubgraphs = subgraphs.toArray()
                                                       .filter(s => s.name != subgraphSchema.name)
                                                       .map(s => check datasource:createSubgraph(s.name, s.url, s.sdl));
        filteredSubgraphs.push(check datasource:createSubgraph(subgraphSchema.name, subgraphSchema.url, subgraphSchema.sdl));
        merger:Supergraph composedSupergraph = check self.mergeSubgraphs(filteredSubgraphs);
        string supergraphSdl = check self.exportSchema(composedSupergraph.schema);

        datasource:Version version = datasource:incrementVersion(
                                        check self.datasource.getLatestVersion() ?: datasource:createInitialVersion()
                                    );
        return datasource:createSupergraphRecord(supergraphSdl, subgraphs, version);
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

    function mergeSubgraphs(merger:Subgraph[] subgraphs) returns merger:Supergraph|error {
        return check (check new merger:Merger(subgraphs)).merge();
    }

    function exportSchema(parser:__Schema schema) returns string|error {
        return check (new exporter:Exporter(schema)).export();
    }
}