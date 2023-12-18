import graphql_schema_registry.datasource;
import ballerinax/mongodb;

configurable mongodb:ConnectionConfig mongoConfig = ?;

public isolated client class MongodbDatasource {
    *datasource:Datasource;

    private final mongodb:Client mongoClient;
    private final string SUPERGRAPHS = "supergraphs";
    private final string SUBGRAPHS = "subgraphs";
    private final string SUPERGRAPH_SUBGRAPHS = "supergraphSubgraphs";

    isolated function init() returns error? {
        self.mongoClient = check new(mongoConfig);
    }

    isolated resource function get supergraphs() returns datasource:Supergraph[]|datasource:Error {
        datasource:Supergraph[] supergraphs = [];
        string[] versions = check self->/versions;
        foreach string version in versions {
            datasource:Supergraph supergraph = check self->/supergraphs/[version];
            supergraphs.push(supergraph);
        }
        return supergraphs;
    }

    isolated resource function get supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
        stream<datasource:Supergraph, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUPERGRAPHS, filter = { version }, projection = { _id: 0 });
        if find !is stream<datasource:Supergraph, error?> {
            return error datasource:Error(find.message());
        }
        record {|datasource:Supergraph value;|}|error? next = find.next();
        if next is error {
            return error datasource:Error(next.message());
        }
        if next is () {
            return error datasource:Error(string `No supergraph found with version '${version}'`);
        }

        return next.value;
    }

    isolated resource function get supergraphs/[string version]/subgraphs() returns datasource:Subgraph[]|datasource:Error {
        stream<datasource:SupergraphSubgraph, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error supergraphSubgraphs = self.mongoClient->find(self.SUPERGRAPH_SUBGRAPHS, filter = { supergraphVersion: version }, projection = { _id: 0 });
        if supergraphSubgraphs !is stream<datasource:SupergraphSubgraph, error?> {
            return error datasource:Error(supergraphSubgraphs.message());
        }
        datasource:SupergraphSubgraph[]|error out = from var subgs in supergraphSubgraphs select subgs;
        if out is error {
            return error datasource:Error(out.message());
        }
        if out.length() == 0 {
            return error datasource:Error(string `No supergraph found with version '${version}'`);
        }

        datasource:Subgraph[] subgraphs = [];
        foreach var subgraphId in out {
            datasource:Subgraph subgraph = check self->/subgraphs/[subgraphId.subgraphId]/[subgraphId.subgraphName];
            subgraphs.push(subgraph);
        }
        return subgraphs;
    }

    isolated resource function post supergraphs(datasource:SupergraphInsert data) returns datasource:Error? {
        string[] versions = check self->/versions;
        if self.hasVersion(versions, data.version) {
            return error datasource:Error(string `A supergraph already exists with the given version '${data.version}'`);
        }

        mongodb:Error? insert = self.mongoClient->insert(data, self.SUPERGRAPHS);
        if insert is mongodb:DatabaseError {
            return error datasource:Error(insert.message());
        }
    }

    // isolated resource function put supergraphs/[string version](datasource:SupergraphUpdate value) returns datasource:Supergraph|datasource:Error {
    // }

    // isolated resource function delete supergraphs/[string version]() returns datasource:Supergraph|datasource:Error {
    // }

    isolated resource function get versions() returns string[]|datasource:Error {
        stream<record { string version; }, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUPERGRAPHS, projection = { version: 1 });
        if find !is stream<record { string version; }, error?> {
            return error datasource:Error(find.message());
        }
        string[]|error versions = from var supVer in find select supVer.version;
        if versions is error {
            return error datasource:Error(versions.message());
        }
        return versions;
    }

    isolated resource function get subgraphs() returns datasource:Subgraph[]|datasource:Error {
        stream<datasource:Subgraph, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUBGRAPHS);
        if find !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(find.message());
        }
        datasource:Subgraph[]|error subgraphs = from var supVer in find select supVer;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs;
    }

    isolated resource function get subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
        stream<datasource:Subgraph, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUBGRAPHS, filter = { id, name }, projection = { _id: 0 }, 'limit = 1);
        if find !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(find.message());
        }
        datasource:Subgraph[]|error subgraphs = from var supVer in find limit 1 select supVer;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs[0];
    }

    isolated resource function get subgraphs/[string name]() returns datasource:Subgraph[]|datasource:Error {
        stream<datasource:Subgraph, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUBGRAPHS, filter = { name }, projection = { _id: 0 });
        if find !is stream<datasource:Subgraph, error?> {
            return error datasource:Error(find.message());
        }
        datasource:Subgraph[]|error subgraphs = from var supVer in find select supVer;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs;
    }

    isolated resource function post subgraphs(datasource:SubgraphInsert data) returns [int, string]|datasource:Error {
        int|mongodb:Error count = self.mongoClient->countDocuments(self.SUBGRAPHS, filter = { name: data.name });
        if count is mongodb:Error {
            return error datasource:Error(count.message());
        }
        int nextId = count + 1;
        datasource:Subgraph subgraph = {
            id: nextId,
            name: data.name,
            url: data.url,
            schema: data.schema
        };
        mongodb:Error? insert = self.mongoClient->insert(subgraph, self.SUBGRAPHS);
        if insert is mongodb:DatabaseError {
            return error datasource:Error(insert.message());
        }
        return [nextId, data.name];
    }

    // isolated resource function put subgraphs/[int id]/[string name](datasource:SubgraphUpdate value) returns datasource:Subgraph|datasource:Error {
    // }

    // isolated resource function delete subgraphs/[int id]/[string name]() returns datasource:Subgraph|datasource:Error {
    // }

    isolated resource function get supergraphsubgraphs/[int subgraphId]/[string subgraphName]/[string supergraphVersion]() returns datasource:SupergraphSubgraph|datasource:Error {
        stream<record { datasource:SupergraphSubgraph subgraph; }, error?>|mongodb:DatabaseError|mongodb:ApplicationError|error find = self.mongoClient->find(self.SUPERGRAPH_SUBGRAPHS, filter = { subgraphId, subgraphName, supergraphVersion }, 'limit = 1);
        if find !is stream<record { datasource:SupergraphSubgraph subgraph; }, error?> {
            return error datasource:Error(find.message());
        }
        datasource:SupergraphSubgraph[]|error subgraphs = from var supVer in find limit 1 select supVer.subgraph;
        if subgraphs is error {
            return error datasource:Error(subgraphs.message());
        }
        return subgraphs[0];
    }

    isolated resource function get supergraphsubgraphs() returns datasource:SupergraphSubgraph[]|datasource:Error {
        return error datasource:Error("Not implemented yet");
    }

    // isolated resource function get supergraphsubgraphs/[int id]() returns datasource:SupergraphSubgraph|datasource:Error {
    // }

    isolated resource function post supergraphsubgraphs(datasource:SupergraphSubgraphInsert[] data) returns int[]|datasource:Error {
        int|mongodb:Error documentCount = self.mongoClient->countDocuments(self.SUPERGRAPH_SUBGRAPHS);
        if documentCount is mongodb:Error {
            return error datasource:Error(documentCount.message());
        }
        int nextKey = documentCount + 1;
        int[] keys = [];
        foreach datasource:SupergraphSubgraphInsert 'record in data.clone() {
            datasource:SupergraphSubgraph insert = {
                id: nextKey,
                subgraphId: 'record.subgraphId,
                subgraphName: 'record.subgraphName,
                supergraphVersion: 'record.supergraphVersion
            };
            mongodb:Error? insertResult = self.mongoClient->insert(insert, self.SUPERGRAPH_SUBGRAPHS);
            if insertResult is mongodb:DatabaseError {
                return error datasource:Error(insertResult.message());
            }
            keys.push(nextKey);
            nextKey += 1;
        }
        return keys.clone();
    }

    isolated resource function put supergraphsubgraphs/[int id](datasource:SupergraphSubgraphUpdate data) returns datasource:SupergraphSubgraph|datasource:Error {
        datasource:SupergraphSubgraph update = {
            id,
            subgraphId: data.subgraphId,
            subgraphName: data.subgraphName,
            supergraphVersion: data.supergraphVersion 
        };
        int|mongodb:Error updateResult = self.mongoClient->update(update, self.SUPERGRAPH_SUBGRAPHS, filter = { id });
        if updateResult is mongodb:Error {
            return error datasource:Error(updateResult.message());
        }
        return update;
    }

    isolated function hasVersion(string[] versions, string version) returns boolean {
        return versions.indexOf(version) !is ();
    }
}