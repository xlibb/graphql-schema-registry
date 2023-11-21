import graphql_schema_registry.merger;
import graphql_schema_registry.parser;
import ballerina/regex;

public function createSupergraphRecord(string schema, map<SubgraphSchema> subgraphs, Version version) returns SupergraphSchema {
    return {
        schema,
        subgraphs,
        version
    };
}

public function createSubgraphSdl(string name, string url, string sdl) returns SubgraphSchema {
    return {
        name,
        url,
        sdl
    };
}

public function createSubgraph(SubgraphSchema subgraphSchema) returns merger:Subgraph|error {
    parser:__Schema schema = check (new parser:Parser(subgraphSchema.sdl, parser:SUBGRAPH_SCHEMA)).parse();
    return {
        name: subgraphSchema.name,
        url: subgraphSchema.url,
        schema: schema
    };
}

public function getVersionAsString(Version version) returns string {
    return string:'join(".", version.breaking.toBalString(), version.dangerous.toBalString(), version.safe.toBalString());
}

public function getVersionFromString(string version) returns Version|error {
    string[] versions = regex:split(version, "\\.");
    int[] versionValues = versions.'map(v => check int:fromString(v));
    return createVersion(
        breaking = versionValues[0],
        dangerous = versionValues[1],
        safe = versionValues[2]
    );
}

public function createInitialVersion() returns Version {
    return createVersion(0, 0, 0);
}

public function incrementVersion(Version version, VersionIncrementOrder 'order = DANGEROUS) returns Version {
    match 'order {
        BREAKING => {
            return createVersion(
                breaking = version.breaking + 1,
                dangerous = 0,
                safe = 0
            );
        }
        DANGEROUS => {
            return createVersion(
                breaking = version.breaking,
                dangerous = version.dangerous + 1,
                safe = 0
            );
        }
        SAFE => {
            return createVersion(
                breaking = version.breaking,
                dangerous = version.dangerous,
                safe = version.safe + 1
            );
        }
        _ => {
            return version;
        }
    }
}

public function createVersion(int breaking, int dangerous, int safe) returns Version {
    return {
        breaking,
        dangerous,
        safe
    };
}