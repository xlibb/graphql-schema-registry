import graphql_schema_registry.datasource;

type SupergraphSubgraph record {|
    readonly string supergraphVersion;
    readonly string subgraphName;
    string subgraphVersion;
|};

public isolated client class InMemoryDatasource {
    *datasource:Datasource;

    private final table<datasource:Supergraph> key(version) supergraphTable;
    private final table<datasource:Subgraph> key(version, name) subgraphTable;
    private final table<SupergraphSubgraph> key(supergraphVersion, subgraphName) supergraphSubgraphTable;

    public function init() {
        self.supergraphTable = table [];
        self.subgraphTable = table [];
        self.supergraphSubgraphTable = table [];
    }

    isolated resource function get supergraphs() returns datasource:Supergraph[]|datasource:Error {
        lock {
            return self.supergraphTable.toArray().clone();
        }
    }

    isolated resource function get supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
        lock {
            if !self.supergraphTable.hasKey(version) {
                return error datasource:Error(string `No supergraph found with version '${version}'.`);
            }
            return self.supergraphTable.get(version).clone();
        }
    }

    isolated resource function get supergraphs/[string version]/subgraphs() returns datasource:Subgraph[]|datasource:Error {
        lock {
            table<datasource:Subgraph> tableResult = from var 'join in self.supergraphSubgraphTable
                                                     from var subgraph in self.subgraphTable
                                                     where 'join.supergraphVersion === version && 'join.subgraphVersion === subgraph.version && 'join.subgraphName === subgraph.name
                                                     select subgraph;
            return tableResult.clone().toArray();
        }
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        lock {
            if self.supergraphTable.hasKey(data.version) {
                return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
            }
            datasource:Supergraph supergraph = {
                version: data.version,
                schema: data.schema,
                apiSchema: data.apiSchema
            };
            self.supergraphTable.add(supergraph);
            foreach datasource:SubgraphId id in data.clone().subgraphs {
                self.supergraphSubgraphTable.add({ 
                    supergraphVersion: data.version,
                    subgraphVersion: id.version,
                    subgraphName: id.name 
                });
            }
        }
    }

    isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate data) returns datasource:Error? {
        lock {
            datasource:Supergraph updatedSupergraph = {
                version,
                schema: data.schema,
                apiSchema: data.apiSchema
            };
            self.supergraphTable.add(updatedSupergraph);
            foreach datasource:SubgraphId id in data.clone().subgraphs {
                self.supergraphSubgraphTable.put({ 
                    supergraphVersion: data.version,
                    subgraphName: id.name,
                    subgraphVersion: id.version
                });
            }
        }
    }

    // isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate value) returns datasource:Supergraph|datasource:Error {
    // }

    // isolated resource function delete supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
    // }

    isolated resource function get versions() returns string[]|datasource:Error {
        lock {
            string[] version = from var supergraph in self.supergraphTable
                               select supergraph.version;
            return version.clone();
        }
    }

    isolated resource function get subgraphs(string? name = ()) returns datasource:Subgraph[]|datasource:Error {
        lock {
            return self.subgraphTable.toArray().clone();
        }
    }

    isolated resource function get subgraphs/[string name]/[string version]() returns datasource:Subgraph|datasource:Error {
        lock {
            if !self.subgraphTable.hasKey([version, name]) {
                return error datasource:Error(string `A subgraph with the given name '${name}' and version '${version}' doesn't exist.`);
            }
            return self.subgraphTable.get([version, name]).clone();
        }
    }

    isolated resource function get subgraphs/[string name]() returns datasource:Subgraph[]|datasource:Error {
        lock {
            table<datasource:Subgraph> result = from var subgraph in self.subgraphTable
                                                where subgraph.name == name
                                                select subgraph;
            return result.toArray().clone();
        }
    }

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns datasource:Subgraph|datasource:Error {
        lock {
            int[] subgraphVersions = from var subgraph in self.subgraphTable
                        where subgraph.name == data.name
                        order by subgraph.version descending
                        select check self.subgraphIdFromString(subgraph.version);
            int nextVersion = (subgraphVersions.length() > 0 ? subgraphVersions[0] : 0) + 1;
            datasource:Subgraph subgraph = {
                version: nextVersion.toString(),
                name: data.name,
                url: data.url,
                schema: data.schema
            };
            self.subgraphTable.add(subgraph);
            return subgraph.clone();
        }
    }

    // isolated resource function delete subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
    // }

    isolated function subgraphIdFromString(string strId) returns int|datasource:Error {
        int|error id = int:fromString(strId);
        if id is error {
            return error datasource:Error(id.message());
        }
        return id;
    }
}