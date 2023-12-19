# Description.
public type Datasource isolated client object {

    isolated resource function get supergraphs() returns Supergraph[]|Error;

    isolated resource function get supergraphs/[string version]() returns Supergraph|Error;

    isolated resource function get supergraphs/[string version]/subgraphs() returns Subgraph[]|Error;

    isolated resource function post supergraphs(SupergraphInsert data) returns Error?;

    isolated resource function put supergraphs/[string version](SupergraphUpdate data) returns Error?;

    // isolated resource function delete supergraphs/[string version]() returns Supergraph|Error;

    isolated resource function get subgraphs(string? name = ()) returns Subgraph[]|Error;

    isolated resource function get subgraphs/[string id]/[string name]() returns Subgraph|Error;

    isolated resource function post subgraphs(SubgraphInsert data) returns Subgraph|Error;

    // isolated resource function put subgraphs/[int id]/[string name](SubgraphUpdate value) returns Subgraph|Error;

    // isolated resource function delete subgraphs/[int id]/[string name]() returns Subgraph|Error;

};