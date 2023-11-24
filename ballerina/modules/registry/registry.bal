import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import ballerina/lang.regexp as regex;

public class Registry {

    private datasource:Datasource datasource;

    public function init(datasource:Datasource datasource) {
        self.datasource = datasource;
    }

    public function publishSubgraph(Subgraph input) returns Supergraph|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        Supergraph generatedSupergraph = check self.generateSupergraph(input, subgraphs);

        subgraphs[input.name] = check self.registerSubgraph(input);
        check self.registerSupergraph(generatedSupergraph, subgraphs.toArray());
    
        return generatedSupergraph;
    }

    public function dryRun(Subgraph input) returns Supergraph|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return check self.generateSupergraph(input, subgraphs);
    }

    public function getLatestSupergraph() returns Supergraph|datasource:Error|RegistryError {
        datasource:Supergraph supergraph = check self.getLatestSupergraphRecord();
        return {
            schema: supergraph.schema,
            apiSchema: supergraph.apiSchema,
            version: supergraph.version,
            subgraphs: supergraph.subgraphs.map(s => { name: s.name, url: s.url, schema: s.schema })
        };
    }

    function getLatestSupergraphRecord() returns datasource:Supergraph|datasource:Error|RegistryError {
        string? latestVersion = check self.getLatestSupergraphVersion();
        if latestVersion is () {
            return error RegistryError("No registered supergraph");
        }
        return check self.getSupergraph(latestVersion);
    }

    function generateSupergraph(Subgraph input, map<datasource:Subgraph> existingSubgraphs) returns Supergraph|datasource:Error|RegistryError|error {
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
            version: nextVersion
        };
        
    }

    function composeSupergraph(Subgraph[] subgraphs) returns ComposedSupergraphSchemas|datasource:Error|RegistryError|error {
        merger:Subgraph[] mergingSubgraphs = subgraphs.map(s => check self.parseSubgraph(s.name, s.url, s.schema));
        merger:Supergraph composedSupergraph = check self.mergeSubgraphs(mergingSubgraphs);

        string supergraphSdl = check self.exportSchema(composedSupergraph.schema);
        string apiSchemaSdl = check self.exportSchema(merger:getApiSchema(composedSupergraph.schema));

        return {
            schema: supergraphSdl,
            apiSchema: apiSchemaSdl
        };
    }

    function registerSubgraph(Subgraph input) returns datasource:Subgraph|datasource:Error {
        [int, string] persistedSubgraph = check self.datasource->/subgraphs.post({ name: input.name, url: input.url, schema: input.schema });
        return {
            id: persistedSubgraph[0],
            name: persistedSubgraph[1],
            url: input.url,
            schema: input.schema
        };
    }

    function registerSupergraph(Supergraph input, datasource:Subgraph[] inputSubgraphs) returns datasource:Error? {
        check self.datasource->/supergraphs.post({
            version: input.version,
            schema: input.schema,
            apiSchema: input.apiSchema,
            subgraphs: inputSubgraphs
        });
        _ = check self.datasource->/supergraphsubgraphs.post(
            inputSubgraphs.map(s => {
                supergraphVersion: input.version,
                subgraphId: s.id,
                subgraphName: s.name
            })
        );
    }

    function getSubgraph(int id, string name) returns datasource:Subgraph|datasource:Error {
        return check self.datasource->/subgraphs/[id]/[name];
    }

    function getSubgraphsOfSupergraphAsMap(string version) returns map<datasource:Subgraph>|datasource:Error {
        datasource:Supergraph supergraph = check self.getSupergraph(version);
        map<datasource:Subgraph> subgraphs = {};
        foreach datasource:Subgraph subgraph in supergraph.subgraphs {
            subgraphs[subgraph.name] = subgraph;
        }
        return subgraphs;
    }

    function getLatestSubgraphs() returns map<datasource:Subgraph>|datasource:Error {
        string? version = check self.getLatestSupergraphVersion();
        return version !is () ? check self.getSubgraphsOfSupergraphAsMap(version) : {};
    }

    function getSupergraph(string version) returns datasource:Supergraph|datasource:Error {
        return check self.datasource->/supergraphs/[version];
    }

    function getLatestSupergraphVersion() returns string?|datasource:Error {
        string[] versions = check self.getVersions();
        if versions.length() <= 0 {
            return ();
        }
        string[] sortedVersions = versions.sort();
        return sortedVersions[sortedVersions.length() - 1];
    }

    function getVersions() returns string[]|datasource:Error {
        return check self.datasource->/versions;
    }

    function createInitialVersion() returns string {
        return "0.0.0";
    }

    function incrementVersion(string version, VersionIncrementOrder 'order = DANGEROUS) returns string|RegistryError|error {
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

    function createVersion(int breaking, int dangerous, int safe) returns string {
        return string `${breaking}.${dangerous}.${safe}`;
    }

    function mergeSubgraphs(merger:Subgraph[] subgraphs) returns merger:Supergraph|error {
        return check (check new merger:Merger(subgraphs)).merge();
    }

    function exportSchema(parser:__Schema schema) returns string|exporter:ExportError {
        return check (new exporter:Exporter(schema)).export();
    }

    function parseSubgraph(string name, string url, string schema) returns merger:Subgraph|error {
        parser:__Schema parsedSchema = check (new parser:Parser(schema, parser:SUBGRAPH_SCHEMA)).parse();
        return {
            name: name,
            url: url,
            schema: parsedSchema
        };
    }
}