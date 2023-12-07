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

    public isolated function publishSubgraph(Subgraph input, boolean isForced) returns CompositionResult|parser:SchemaError[]|merger:MergeError[]|OperationCheckError[]|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        CompositionResult|parser:SchemaError[]|merger:MergeError[]|OperationCheckError[] generatedSupergraph = check self.generateSupergraph(input, subgraphs, isForced);
        if generatedSupergraph is parser:SchemaError[]|merger:MergeError[]|OperationCheckError[] {
            return generatedSupergraph;
        }

        check self.storeSchemas(subgraphs, input, generatedSupergraph);
    
        return generatedSupergraph;
    }

    public isolated function dryRun(Subgraph input, boolean isForced) returns CompositionResult|parser:SchemaError[]|merger:MergeError[]|OperationCheckError[]|error {
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return check self.generateSupergraph(input, subgraphs, isForced);
    }

    public isolated function getLatestSupergraph() returns Supergraph|error {
        datasource:Supergraph supergraph = check self.getLatestSupergraphRecord();
        map<datasource:Subgraph> subgraphs = check self.getLatestSubgraphs();
        return {
            schemaSdl: supergraph.schema,
            apiSchemaSdl: supergraph.apiSchema,
            version: supergraph.version,
            subgraphs: subgraphs.map(s => { name: s.name, url: s.url, schema: s.schema }).toArray()
        };
    }

    public isolated function getSubgraphByName(string name) returns Subgraph|error {
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
            return error SubgraphNotFound(string `No subgraph found with the name '${name}'`);
        }
    }

    public isolated function getDiff(string newVersion, string oldVersion) returns differ:SchemaDiff[]|error {
        datasource:Supergraph newSupergraph = check self.getSupergraph(newVersion);
        datasource:Supergraph oldSupergraph = check self.getSupergraph(oldVersion);

        parser:__Schema|parser:SchemaError[] newSupergraphSchema = self.parseSupergraph(newSupergraph.apiSchema);
        if newSupergraphSchema is parser:SchemaError[] {
            return error Error(string `Corrupted supergraph schema v${newVersion}`);
        }
        parser:__Schema|parser:SchemaError[] oldSupergraphSchema = self.parseSupergraph(oldSupergraph.apiSchema);
        if oldSupergraphSchema is parser:SchemaError[] {
            return error Error(string `Corrupted supergraph schema v${newVersion}`);
        }

        return check differ:diff(newSupergraphSchema, oldSupergraphSchema);
    }

    public isolated function getVersions() returns string[]|datasource:Error {
        return check self.datasource->/versions;
    }

    isolated function storeSchemas(map<datasource:Subgraph> subgraphs, Subgraph input, CompositionResult generatedSupergraph) returns error? {
        string? latestSupergraphVersion = check self.getLatestSupergraphVersion();
        if latestSupergraphVersion is () || latestSupergraphVersion != generatedSupergraph.version {
            subgraphs[input.name] = check self.registerSubgraph(input);
            check self.registerSupergraph(generatedSupergraph.cloneReadOnly(), subgraphs.toArray());
        } else {
            datasource:Subgraph|datasource:Error|SubgraphNotFound currentSubgraph = self.getLatestSubgraphByName(input.name);
            if currentSubgraph is datasource:Error {
                return currentSubgraph;
            }
            subgraphs[input.name] = check self.registerSubgraph(input);
            int updatedSubgraphId = subgraphs.get(input.name).id;
            
            if currentSubgraph !is SubgraphNotFound {
                check self.updateSupergraphSubgraph(input.name, currentSubgraph.id, updatedSubgraphId, latestSupergraphVersion);
            } else {
                check self.registerSupergraphSubgraph(
                        [{
                            supergraphVersion: latestSupergraphVersion,
                            subgraphId: updatedSubgraphId,
                            subgraphName: input.name
                        }]
                    );
            }
        }
    }

    isolated function getLatestSupergraphRecord() returns datasource:Supergraph|datasource:Error|SupergraphNotFound {
        string? latestVersion = check self.getLatestSupergraphVersion();
        if latestVersion is () {
            return error SupergraphNotFound("No registered supergraph");
        }
        return check self.getSupergraph(latestVersion);
    }

    isolated function generateSupergraph(Subgraph input, map<datasource:Subgraph> existingSubgraphs, boolean isForced) returns CompositionResult|merger:MergeError[]|parser:SchemaError[]|OperationCheckError[]|error {
        map<Subgraph> mergingSubgraphs = existingSubgraphs.map(s => { name: s.name, url: s.url, schema: s.schema });
        if mergingSubgraphs.hasKey(input.name) && mergingSubgraphs.get(input.name).schema == input.schema {
            return error Error("No subgraph change");
        }
        mergingSubgraphs[input.name] = { name: input.name, url: input.url, schema: input.schema };
        Subgraph[] mergingSubgraphList = mergingSubgraphs.toArray();
        ComposedSupergraphSchemas|parser:SchemaError[]|merger:MergeError[] composeResult = check self.composeSupergraph(mergingSubgraphList);
        if composeResult is parser:SchemaError[]|merger:MergeError[] {
            return composeResult;
        }

        DiffResult|OperationCheckError[]|parser:SchemaError[] diffResult = check self.getDiffAndNextVersion(composeResult, isForced);
        if diffResult !is DiffResult {
            return diffResult;
        }

        merger:Hint[] filteredHints = merger:filterHints([input.name], composeResult.hints);
        string[] hintMessages = merger:printHints(filteredHints);

        return {
            schemaSdl: composeResult.schemaSdl,
            apiSchemaSdl: composeResult.apiSchemaSdl,
            subgraphs: mergingSubgraphList,
            version: diffResult.version,
            hints: hintMessages,
            diffs: diffResult.diffs
        };
        
    }

    isolated function composeSupergraph(Subgraph[] subgraphs) returns ComposedSupergraphSchemas|parser:SchemaError[]|merger:MergeError[]|error {
        // merger:Subgraph[] mergingSubgraphs = subgraphs.map(s => check self.parseSubgraph(s.name, s.url, s.schema));
        merger:Subgraph[] mergingSubgraphs = [];
        foreach Subgraph subgraph in subgraphs {
            merger:Subgraph|parser:SchemaError[] parsedSubgraph = self.parseSubgraph(subgraph.name, subgraph.url, subgraph.schema);
            if parsedSubgraph is parser:SchemaError[] {
                return parsedSubgraph;
            }
            mergingSubgraphs.push(parsedSubgraph);
        }
        merger:SupergraphMergeResult|merger:MergeError[] composedSupergraph = check self.mergeSubgraphs(mergingSubgraphs);
        if composedSupergraph is merger:MergeError[] {
            return composedSupergraph;
        }

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

    isolated function getDiffAndNextVersion(ComposedSupergraphSchemas composeResult, boolean isForced) returns DiffResult|OperationCheckError[]|parser:SchemaError[]|error {
        datasource:Supergraph|datasource:Error|SupergraphNotFound latestSupergraph = self.getLatestSupergraphRecord();
        if latestSupergraph is datasource:Error {
            return latestSupergraph;
        }
        
        string latestVersion;
        differ:SchemaDiff[] diffs = [];
        differ:DiffSeverity? incrementOrder;
        if latestSupergraph !is SupergraphNotFound {
            latestVersion = latestSupergraph.version;
            parser:__Schema|parser:SchemaError[] parsedSupergraph = self.parseSupergraph(latestSupergraph.apiSchema);
            if parsedSupergraph is parser:SchemaError[] {
                return parsedSupergraph;
            }
            diffs = check differ:diff(composeResult.apiSchema, parsedSupergraph);
            differ:DiffSeverity? majorSeverity = differ:getMajorSeverity(diffs.map(d => d.severity));
            if majorSeverity is differ:BREAKING && !isForced {
                return diffs.filter(e => e.severity is differ:BREAKING)
                            .map(e => error OperationCheckError(differ:getDiffMessage(e), diff = e));
            }
            incrementOrder = majorSeverity;
        } else {
            diffs = check differ:diff(composeResult.apiSchema, ());
            latestVersion = self.createInitialVersion();
            incrementOrder = differ:DANGEROUS;
        }
        string nextVersion = check self.incrementVersion(latestVersion, incrementOrder);
        return {
            version: nextVersion,
            diffs 
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
        check self.registerSupergraphSubgraph(
            inputSubgraphs.map(isolated function (datasource:Subgraph s) returns datasource:SupergraphSubgraphInsert {
                return {
                    supergraphVersion: input.version,
                    subgraphId: s.id,
                    subgraphName: s.name
                };
            })
        );
    }

    isolated function registerSupergraphSubgraph(datasource:SupergraphSubgraphInsert[] data) returns datasource:Error? {
        _ = check self.datasource->/supergraphsubgraphs.post(
                data
            );
    }

    isolated function updateSupergraphSubgraph(string subgraphName, int currentSubgraphId, int updatedSubgraphId, string version) returns error? {
        datasource:SupergraphSubgraph supergraphSubgraph = check self.datasource->/supergraphsubgraphs/[currentSubgraphId]/[subgraphName]/[version]();
        _ = check self.datasource->/supergraphsubgraphs/[supergraphSubgraph.id].put({
            supergraphVersion: version,
            subgraphId: updatedSubgraphId,
            subgraphName: subgraphName
        });
    }

    isolated function getLatestSubgraphByName(string name) returns datasource:Subgraph|datasource:Error|SubgraphNotFound {
        datasource:Subgraph[] subgraphs = check self.datasource->/subgraphs/[name];
        if subgraphs.length() > 0 {
            datasource:Subgraph latestSubgraph = subgraphs.sort(
                                                    "descending", 
                                                    key = isolated function (datasource:Subgraph s) returns int {
                                                        return s.id;
                                                    })[0];
            return latestSubgraph;
        } else {
            return error SubgraphNotFound(string `No subgraph found with the name '${name}'`);
        }
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

    isolated function createInitialVersion() returns string {
        return "0.0.0";
    }

    isolated function incrementVersion(string version, differ:DiffSeverity? 'order = differ:DANGEROUS) returns string|error {
        int[] numbers = regex:split(re `\.`, version).'map(v => check int:fromString(v));
        if numbers.length() != 3 {
            return error Error(string `Invalid version number '${version}'`);
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

    isolated function mergeSubgraphs(merger:Subgraph[] subgraphs) returns merger:SupergraphMergeResult|merger:MergeError[]|error {
        return check (check new merger:Merger(subgraphs)).merge();
    }

    isolated function exportSchema(parser:__Schema schema) returns string|exporter:ExportError {
        return check (new exporter:Exporter(schema)).export();
    }

    isolated function parseSubgraph(string name, string url, string schema) returns merger:Subgraph|parser:SchemaError[] {
        parser:Parser parser = new(schema, parser:SUBGRAPH_SCHEMA);
        parser:__Schema|parser:SchemaError[] parsedSchema = parser.parse();
        if parsedSchema is parser:SchemaError[] {
            return parsedSchema;
        }
        return {
            name: name,
            url: url,
            schema: parsedSchema
        };
    }

    isolated function parseSupergraph(string schema) returns parser:__Schema|parser:SchemaError[] {
        parser:Parser parser = new(schema, parser:SUPERGRAPH_SCHEMA);
        parser:__Schema|parser:SchemaError[] parsedSchema = parser.parse();
        if parsedSchema is parser:SchemaError[] {
            return parsedSchema;
        }
        return parsedSchema;
    }
}