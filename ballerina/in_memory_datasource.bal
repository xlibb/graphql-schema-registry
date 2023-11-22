import graphql_schema_registry.datasource;

type SupergraphSchemaRecord record {|
    readonly datasource:Version version;
    string sdl;
    int[] subgraphs;
|};

type SubgraphSchemaRecord record {|
    readonly int id;
    string sdl;
    string name;
    string url;
|};

class InMemoryDatasource {
    *datasource:Datasource;

    private table<SupergraphSchemaRecord> key(version) supergraphRecords;
    private table<SubgraphSchemaRecord> key(id) subgraphRecords;

    public function init() {
        self.supergraphRecords = table [];
        self.subgraphRecords = table [];
    }

    public function getLatestSchemas() returns datasource:SupergraphSchema?|datasource:DatasourceError {
        datasource:Version? latestVersion = check self.getLatestVersion();
        if latestVersion is datasource:Version {
            return check self.getSchemasByVersion(latestVersion);
        } else {
            return ();
        }
    }

    public function getLatestVersion() returns datasource:Version?|datasource:DatasourceError {
        datasource:Version[] versions = self.supergraphRecords.keys();
        if versions.length() > 0 {
            return versions[versions.length() - 1];
        } 
        return ();
    }

    public function getSchemasByVersion(datasource:Version version) returns datasource:SupergraphSchema|datasource:DatasourceError {
        readonly & datasource:Version readonlyVersion = version.cloneReadOnly();
        if self.supergraphRecords.hasKey(readonlyVersion) {
            SupergraphSchemaRecord supergraphRecord = self.supergraphRecords.get(readonlyVersion);
            return self.recordToSupergraphSchema(supergraphRecord);
        } else {
            return error datasource:DatasourceError(string `Cannot find supergraph with version '${datasource:getVersionAsString(readonlyVersion)}'`);
        }
    }

    public function registerSubgraph(datasource:InputSubgraph subgraph) returns datasource:SubgraphSchema|datasource:DatasourceError {
        SubgraphSchemaRecord 'record = {
            id: self.subgraphRecords.nextKey(),
            name: subgraph.name,
            url: subgraph.url,
            sdl: subgraph.sdl
        };
        self.subgraphRecords.add('record);
        return self.recordToSubgraphSchema('record);
    }

    public function registerSupergraph(datasource:SupergraphSchema schema) returns datasource:SupergraphSchema|datasource:DatasourceError {
        SupergraphSchemaRecord 'record = check self.supergraphSchemaToRecord(schema);
        self.supergraphRecords.add('record);
        return schema;
    }

    function subgraphSchemaToRecord(datasource:SubgraphSchema schema) returns SubgraphSchemaRecord|datasource:DatasourceError {
        int id = check self.getSubgraphId(schema.id);
        return {
            id: id,
            name: schema.name,
            url: schema.url,
            sdl: schema.sdl
        };
    }

    function recordToSubgraphSchema(SubgraphSchemaRecord 'record) returns datasource:SubgraphSchema {
        return {
            id: 'record.id.toString(),
            name: 'record.name,
            url: 'record.url,
            sdl: 'record.sdl
        };
    }

    function supergraphSchemaToRecord(datasource:SupergraphSchema schema) returns SupergraphSchemaRecord|datasource:DatasourceError {
        int[] subgraphs = schema.subgraphs.toArray().map(s => check self.getSubgraphId(s.id));
        return {
            version: schema.version.cloneReadOnly(),
            sdl: schema.schema,
            subgraphs: subgraphs
        };
    }

    function recordToSupergraphSchema(SupergraphSchemaRecord 'record) returns datasource:SupergraphSchema {
        map<datasource:SubgraphSchema> subgraphs = map from var subgraph in self.subgraphRecords
                                                   join var currentSubgraph in 'record.subgraphs
                                                   on subgraph.id equals currentSubgraph
                                                   select [subgraph.name, self.recordToSubgraphSchema(subgraph)];
        return {
            version: 'record.version,
            schema: 'record.sdl,
            subgraphs: subgraphs
        };
    }

    function getSubgraphId(string stringId) returns int|datasource:DatasourceError {
        int|error id = int:fromString(stringId);
        if id is error {
            return error datasource:DatasourceError(string `Cannot convert id '${stringId}'.`);
        }
        return id;
    }
}