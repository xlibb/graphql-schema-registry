import graphql_schema_registry.datasource;

public isolated client class InMemoryDatasource {
    *datasource:Datasource;

    private final table<datasource:Supergraph> key(version) supergraphTable;
    private final table<datasource:Subgraph> key(id, name) subgraphTable;
    private final table<datasource:SupergraphSubgraph> key(id) supergraphSubgraphTable;

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
                                                     where 'join.supergraphVersion === version && 'join.subgraphId === subgraph.id && 'join.subgraphName === subgraph.name
                                                     select subgraph;
            return tableResult.clone().toArray();
        }
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        lock {
            if self.supergraphTable.hasKey(data.version) {
                return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
            }
            self.supergraphTable.add(data.clone());
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

    isolated resource function get subgraphs() returns datasource:Subgraph[]|datasource:Error {
        lock {
            return self.subgraphTable.toArray().clone();
        }
    }

    isolated resource function get subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
        lock {
            if !self.subgraphTable.hasKey([id, name]) {
                return error datasource:Error(string `A subgraph with the given name '${name}' and id '${id}' doesn't exist.`);
            }
            return self.subgraphTable.get([id, name]).clone();
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

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns [int, string]|datasource:Error {
        lock {
            int[] ids = from var subgraph in self.subgraphTable
                        where subgraph.name == data.name
                        order by subgraph.id descending
                        select subgraph.id;
            int nextId = (ids.length() > 0 ? ids[0] : 0) + 1;
            self.subgraphTable.add({
                id: nextId,
                name: data.name,
                url: data.url,
                schema: data.schema
            });
            return [nextId, data.name];
        }
    }

    // isolated resource function put subgraphs/[int id]/[string name](datasource:SubgraphUpdate value) returns datasource:Subgraph|datasource:Error {
    // }

    // isolated resource function delete subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
    // }

    isolated resource function get supergraphsubgraphs() returns datasource:SupergraphSubgraph[]|datasource:Error {
        lock {
            return self.supergraphSubgraphTable.toArray().clone();
        }
    }

    // isolated resource function get supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }

    isolated resource function post supergraphsubgraphs(datasource:SupergraphSubgraphInsert[] data) returns int[]|datasource:Error {
        lock {
            int[] keys = [];
            foreach datasource:SupergraphSubgraphInsert 'record in data.clone() {
                    int nextKey = self.supergraphSubgraphTable.nextKey();
                    self.supergraphSubgraphTable.add({
                        id: nextKey,
                        subgraphId: 'record.subgraphId,
                        subgraphName: 'record.subgraphName,
                        supergraphVersion: 'record.supergraphVersion
                    });
                keys.push(nextKey);
            }
            return keys.clone();
        }
    }

    // isolated resource function put supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }

    // isolated resource function delete supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }
}