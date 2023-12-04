import graphql_schema_registry.differ;
public type RegistryError distinct error;

public type OperationCheckError distinct (error & error<record {| differ:SchemaDiff diff; |}>);