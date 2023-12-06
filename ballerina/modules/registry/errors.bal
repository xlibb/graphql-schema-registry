import graphql_schema_registry.differ;
public type Error distinct error;

public type SubgraphNotFound distinct Error;

public type SupergraphNotFound distinct Error;

public type OperationCheckError distinct (error & error<record {| differ:SchemaDiff diff; |}>);