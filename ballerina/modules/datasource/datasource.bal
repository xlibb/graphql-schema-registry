# Description.
public type Datasource isolated client object {

    isolated resource function get supergraphs() returns Supergraph[]|Error;

    isolated resource function get supergraphs/[string version]() returns Supergraph|Error;

    isolated resource function get supergraphs/[string version]/subgraphs() returns Subgraph[]|Error;

    isolated resource function post supergraphs(SupergraphInsert data) returns Error?;

    // isolated resource function put supergraphs/[string version](SupergraphUpdate value) returns Supergraph|Error;

    // isolated resource function delete supergraphs/[string version]() returns Supergraph|Error;

    isolated resource function get versions() returns string[]|Error;

    isolated resource function get subgraphs() returns Subgraph[]|Error;

    isolated resource function get subgraphs/[int id]/[string name]() returns Subgraph|Error;

    isolated resource function get subgraphs/[string name]() returns Subgraph[]|Error;

    isolated resource function post subgraphs(SubgraphInsert data) returns [int, string]|Error;

    // isolated resource function put subgraphs/[int id]/[string name](SubgraphUpdate value) returns Subgraph|Error;

    // isolated resource function delete subgraphs/[int id]/[string name]() returns Subgraph|Error;

    // isolated resource function get supergraphsubgraphs() returns SupergraphSubgraph[]|Error;

    // isolated resource function get supergraphsubgraphs/[int id]() returns SupergraphSubgraph|Error;

    isolated resource function get supergraphsubgraphs/[int subgraphId]/[string subgraphName]/[string supergraphVersion]() returns SupergraphSubgraph|Error;

    isolated resource function post supergraphsubgraphs(SupergraphSubgraphInsert[] data) returns int[]|Error;

    isolated resource function put supergraphsubgraphs/[int id](SupergraphSubgraphUpdate data) returns SupergraphSubgraph|Error;

    // isolated resource function delete supergraphsubgraphs/[int id]() returns SupergraphSubgraph|Error;

};