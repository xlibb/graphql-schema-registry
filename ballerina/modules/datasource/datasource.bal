public type Datasource distinct object {

    public function registerSupergraph(SupergraphSchema schema) returns SupergraphSchema|DatasourceError;
    public function registerSubgraph(InputSubgraph subgraph) returns SubgraphSchema|DatasourceError;
    public function getLatestSchemas() returns SupergraphSchema?|DatasourceError;
    public function getSchemasByVersion(Version version) returns SupergraphSchema|DatasourceError;
    public function getLatestVersion() returns Version?|DatasourceError;

};