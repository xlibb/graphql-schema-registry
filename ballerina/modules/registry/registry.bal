import graphql_schema_registry.merger;
import graphql_schema_registry.exporter;
import graphql_schema_registry.parser;
import graphql_schema_registry.datasource;
import ballerina/lang.regexp as regex;
import graphql_schema_registry.differ;

public isolated class Registry {

    private final datasource:Datasource datasource;

    public isolated function init(datasource:Datasource datasource) {
        self.datasource = datasource;
    }

    public isolated function publishSubgraph(Subgraph input) returns CompositionResult|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        CompositionResult generatedSupergraph = check self.generateSupergraph(input, subgraphs);

        subgraphs[input.name] = check self.registerSubgraph(input);
        check self.registerSupergraph(generatedSupergraph.cloneReadOnly(), subgraphs.toArray());
    
        return generatedSupergraph;
    }

    public isolated function dryRun(Subgraph input) returns CompositionResult|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return check self.generateSupergraph(input, subgraphs);
    }

    public isolated function getLatestSupergraph() returns Supergraph|datasource:Error|RegistryError {
        datasource:Supergraph supergraph = check self.getLatestSupergraphRecord();
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return {
            schemaSdl: supergraph.schema,
            apiSchemaSdl: supergraph.apiSchema,
            version: supergraph.version,
            subgraphs: subgraphs.map(s => { name: s.name, url: s.url, schema: s.schema }).toArray()
        };
    }

    public isolated function getSubgraphByName(string name) returns Subgraph|datasource:Error|RegistryError {
        datasource:Subgraph[] subgraphs = check self.datasource->/subgraphs/[name];
        if subgraphs.length() > 0 {
            datasource:Subgraph latestSubgraph = subgraphs.sort(
                                                    "descending", 
                                                    key = isolated function (datasource:Subgraph s) returns int {
                                                        return s.id;
                                                    })[0];
            return {
                name: latestSubgraph.name,
                url: latestSubgraph.url,
                schema: latestSubgraph.schema
            };
        } else {
            return error RegistryError(string `No subgraph found with the name '${name}'`);
        }
    }

    isolated function getLatestSupergraphRecord() returns datasource:Supergraph|datasource:Error|RegistryError {
        string? latestVersion = check self.getLatestSupergraphVersion();
        if latestVersion is () {
            return error RegistryError("No registered supergraph");
        }
        return check self.getSupergraph(latestVersion);
    }

    isolated function generateSupergraph(Subgraph input, map<datasource:Subgraph> existingSubgraphs) returns CompositionResult|datasource:Error|RegistryError|error {
        map<Subgraph> mergingSubgraphs = existingSubgraphs.map(s => { name: s.name, url: s.url, schema: s.schema });
        mergingSubgraphs[input.name] = { name: input.name, url: input.url, schema: input.schema };
        Subgraph[] mergingSubgraphList = mergingSubgraphs.toArray();
        ComposedSupergraphSchemas composeResult = check self.composeSupergraph(mergingSubgraphList);

        datasource:Supergraph|datasource:Error|RegistryError latestSupergraph = self.getLatestSupergraphRecord();
        if latestSupergraph is datasource:Error {
            return latestSupergraph;
        }
        
        string latestVersion;
        differ:SchemaDiff[] diffs = [];
        differ:DiffSeverity incrementOrder;
        if latestSupergraph !is RegistryError {
            latestVersion = latestSupergraph.version;
            diffs = check differ:diff(composeResult.apiSchema, check self.parseSupergraph(latestSupergraph.apiSchema));
            differ:DiffSeverity? majorSeverity = differ:getMajorSeverity(diffs.map(d => d.severity));
            if majorSeverity is () {
                return error RegistryError("No supergraph changes");
            }
            incrementOrder = majorSeverity;
        } else {
            diffs = check differ:diff(composeResult.apiSchema, ());
            latestVersion = self.createInitialVersion();
            incrementOrder = differ:DANGEROUS;
        }
        string nextVersion = check self.incrementVersion(latestVersion, incrementOrder);

        return {
            schemaSdl: composeResult.schemaSdl,
            apiSchemaSdl: composeResult.apiSchemaSdl,
            subgraphs: mergingSubgraphList,
            version: nextVersion,
            hints: composeResult.hints,
            diffs: diffs
        };
        
    }

    isolated function composeSupergraph(Subgraph[] subgraphs) returns ComposedSupergraphSchemas|datasource:Error|RegistryError|error {
        merger:Subgraph[] mergingSubgraphs = subgraphs.map(s => check self.parseSubgraph(s.name, s.url, s.schema));
        merger:SupergraphMergeResult composedSupergraph = check self.mergeSubgraphs(mergingSubgraphs);

        string supergraphSdl = check self.exportSchema(composedSupergraph.result.schema);

        parser:__Schema apiSchema = merger:getApiSchema(composedSupergraph.result.schema);
        string apiSchemaSdl = check self.exportSchema(apiSchema);

        return {
            schema: composedSupergraph.result.schema,
            apiSchema: apiSchema,
            schemaSdl: supergraphSdl,
            apiSchemaSdl: apiSchemaSdl,
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

    isolated function registerSupergraph(CompositionResult & readonly input, datasource:Subgraph[] inputSubgraphs) returns datasource:Error? {
        check self.datasource->/supergraphs.post({
            version: input.version,
            schema: input.schemaSdl,
            apiSchema: input.apiSchemaSdl
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

    isolated function incrementVersion(string version, differ:DiffSeverity 'order = differ:DANGEROUS) returns string|RegistryError|error {
        int[] numbers = regex:split(re `\.`, version).'map(v => check int:fromString(v));
        if numbers.length() != 3 {
            return error RegistryError(string `Invalid version number '${version}'`);
        }
        match 'order {
            differ:BREAKING => {
                return self.createVersion(
                    breaking = numbers[0] + 1,
                    dangerous = 0,
                    safe = 0
                );
            }
            differ:DANGEROUS => {
                return self.createVersion(
                    breaking = numbers[0],
                    dangerous = numbers[1] + 1,
                    safe = 0
                );
            }
            differ:SAFE => {
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
        merger:SupergraphMergeResult|merger:MergeError[]|merger:InternalError|error merged = (check new merger:Merger(subgraphs)).merge();
        if merged is merger:SupergraphMergeResult {
            return merged;
        } else {
            return error("Supergraph merge failure");
        }
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

    isolated function parseSupergraph(string schema) returns parser:__Schema|error {
        parser:__Schema parsedSchema = check (check new parser:Parser(schema, parser:SUPERGRAPH_SCHEMA)).parse();
        return parsedSchema;
    }
}