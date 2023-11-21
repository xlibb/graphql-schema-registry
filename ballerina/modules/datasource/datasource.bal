public type Datasource distinct object {

    public function register(SupergraphSchema records) returns SupergraphSchema|DatasourceError;
    public function getLatestSchemas() returns SupergraphSchema?|DatasourceError;
    public function getSchemasByVersion(Version version) returns SupergraphSchema|DatasourceError;
    public function getLatestVersion() returns Version?|DatasourceError;

};