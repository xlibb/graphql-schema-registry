import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import ballerina/lang.regexp as regex;

public isolated class Registry {

    private final datasource:Datasource datasource;

    public isolated function init(datasource:Datasource datasource) {
        self.datasource = datasource;
    }

    public isolated function publishSubgraph(Subgraph input) returns Supergraph|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        Supergraph generatedSupergraph = check self.generateSupergraph(input, subgraphs);

        subgraphs[input.name] = check self.registerSubgraph(input);
        check self.registerSupergraph(generatedSupergraph.cloneReadOnly(), subgraphs.toArray());
    
        return generatedSupergraph;
    }

    public isolated function dryRun(Subgraph input) returns Supergraph|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return check self.generateSupergraph(input, subgraphs);
    }

    public isolated function getLatestSupergraph() returns Supergraph|datasource:Error|RegistryError {
        datasource:Supergraph supergraph = check self.getLatestSupergraphRecord();
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return {
            schema: supergraph.schema,
            apiSchema: supergraph.apiSchema,
            version: supergraph.version,
            subgraphs: subgraphs.map(s => { name: s.name, url: s.url, schema: s.schema }).toArray(),
            hints: []
        };
    }

    isolated function getLatestSupergraphRecord() returns datasource:Supergraph|datasource:Error|RegistryError {
        string? latestVersion = check self.getLatestSupergraphVersion();
        if latestVersion is () {
            return error RegistryError("No registered supergraph");
        }
        return check self.getSupergraph(latestVersion);
    }

    isolated function generateSupergraph(Subgraph input, map<datasource:Subgraph> existingSubgraphs) returns Supergraph|datasource:Error|RegistryError|error {
        map<Subgraph> mergingSubgraphs = existingSubgraphs.map(s => { name: s.name, url: s.url, schema: s.schema });
        mergingSubgraphs[input.name] = { name: input.name, url: input.url, schema: input.schema };
        Subgraph[] mergingSubgraphList = mergingSubgraphs.toArray();
        ComposedSupergraphSchemas composeResult = check self.composeSupergraph(mergingSubgraphList);
        string nextVersion = check self.incrementVersion(
                                    check self.getLatestSupergraphVersion() ?: self.createInitialVersion());
        // Handle Operation Checks
        return {
            schema: composeResult.schema,
            apiSchema: composeResult.apiSchema,
            subgraphs: mergingSubgraphList,
            version: nextVersion,
            hints: composeResult.hints
        };
        
    }

    isolated function composeSupergraph(Subgraph[] subgraphs) returns ComposedSupergraphSchemas|datasource:Error|RegistryError|error {
        merger:Subgraph[] mergingSubgraphs = subgraphs.map(s => check self.parseSubgraph(s.name, s.url, s.schema));
        merger:SupergraphMergeResult composedSupergraph = check self.mergeSubgraphs(mergingSubgraphs);

        string supergraphSdl = check self.exportSchema(composedSupergraph.result.schema);
        string apiSchemaSdl = check self.exportSchema(merger:getApiSchema(composedSupergraph.result.schema));

        return {
            schema: supergraphSdl,
            apiSchema: apiSchemaSdl,
            hints: composedSupergraph.hints
        };
    }

    isolated function registerSubgraph(Subgraph input) returns datasource:Subgraph|datasource:Error {
        [int, string] persistedSubgraph = check self.datasource->/subgraphs.post({ name: input.name, url: input.url, schema: input.schema });
        return {
            id: persistedSubgraph[0],
            name: persistedSubgraph[1],
            url: input.url,
            schema: input.schema
        };
    }

    isolated function registerSupergraph(Supergraph & readonly input, datasource:Subgraph[] inputSubgraphs) returns datasource:Error? {
        check self.datasource->/supergraphs.post({
            version: input.version,
            schema: input.schema,
            apiSchema: input.apiSchema
        });
        _ = check self.datasource->/supergraphsubgraphs.post(
            inputSubgraphs.map(isolated function (datasource:Subgraph s) returns datasource:SupergraphSubgraphInsert {
                return {
                    supergraphVersion: input.version,
                    subgraphId: s.id,
                    subgraphName: s.name
                };
            })
        );
    }

    isolated function getSubgraph(int id, string name) returns datasource:Subgraph|datasource:Error {
        return check self.datasource->/subgraphs/[id]/[name];
    }

    isolated function getSubgraphsOfSupergraphAsMap(string version) returns map<datasource:Subgraph>|datasource:Error {
        datasource:Subgraph[] subgraphs = check self.datasource->/supergraphs/[version]/subgraphs;
        map<datasource:Subgraph> mappedSubgraphs = {};
        foreach datasource:Subgraph subgraph in subgraphs {
            mappedSubgraphs[subgraph.name] = subgraph;
        }
        return mappedSubgraphs;
    }

    isolated function getLatestSubgraphs() returns map<datasource:Subgraph>|datasource:Error {
        string? version = check self.getLatestSupergraphVersion();
        return version !is () ? check self.getSubgraphsOfSupergraphAsMap(version) : {};
    }

    isolated function getSupergraph(string version) returns datasource:Supergraph|datasource:Error {
        return check self.datasource->/supergraphs/[version];
    }

    isolated function getLatestSupergraphVersion() returns string?|datasource:Error {
        string[] versions = check self.getVersions();
        if versions.length() <= 0 {
            return ();
        }
        string[] sortedVersions = versions.sort();
        return sortedVersions[sortedVersions.length() - 1];
    }

    isolated function getVersions() returns string[]|datasource:Error {
        return check self.datasource->/versions;
    }

    isolated function createInitialVersion() returns string {
        return "0.0.0";
    }

    isolated function incrementVersion(string version, VersionIncrementOrder 'order = DANGEROUS) returns string|RegistryError|error {
        int[] numbers = regex:split(re `\.`, version).'map(v => check int:fromString(v));
        if numbers.length() != 3 {
            return error RegistryError(string `Invalid version number '${version}'`);
        }
        match 'order {
            BREAKING => {
                return self.createVersion(
                    breaking = numbers[0] + 1,
                    dangerous = 0,
                    safe = 0
                );
            }
            DANGEROUS => {
                return self.createVersion(
                    breaking = numbers[0],
                    dangerous = numbers[1] + 1,
                    safe = 0
                );
            }
            SAFE => {
                return self.createVersion(
                    breaking = numbers[0],
                    dangerous = numbers[1],
                    safe = numbers[2] + 1
                );
            }
            _ => {
                return version;
            }
        }
    }

    isolated function createVersion(int breaking, int dangerous, int safe) returns string {
        return string `${breaking}.${dangerous}.${safe}`;
    }

    isolated function mergeSubgraphs(merger:Subgraph[] subgraphs) returns merger:SupergraphMergeResult|error {
        return (check (check new merger:Merger(subgraphs)).merge());
    }

    isolated function exportSchema(parser:__Schema schema) returns string|exporter:ExportError {
        return check (new exporter:Exporter(schema)).export();
    }

    isolated function parseSubgraph(string name, string url, string schema) returns merger:Subgraph|error {
        parser:__Schema parsedSchema = check (new parser:Parser(schema, parser:SUBGRAPH_SCHEMA)).parse();
        return {
            name: name,
            url: url,
            schema: parsedSchema
        };
    }
}