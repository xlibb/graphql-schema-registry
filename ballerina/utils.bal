import ballerina/graphql;
import graphql_schema_registry.merger;
import graphql_schema_registry.parser;
import graphql_schema_registry.registry;

type ErrorDetail record {|
    string message;
    anydata details;
|};

isolated function returnErrors(graphql:Context ctx, graphql:Field 'field, error[] errors) returns error? {
    ErrorDetail[] errorDetails = errors.map(e => { 
        message: e.message(),
        details: check e.detail().ensureType(anydata)
    });

    string message;
    if errors is merger:MergeError[] { 
        message = "Supergraph composition error";
    } else if errors is parser:SchemaError[] { 
        message = "Invalid GraphQL";
    } else if errors is registry:OperationCheckError[] { 
        message = "Operation causes breaking changes";
    } else {
        message = "Error";
    }

    graphql:ErrorDetail errorDetail = {
        message: message,
        locations: ['field.getLocation()],
        path: 'field.getPath(),
        extensions: {
            errors: errorDetails
        }
    };
    graphql:__addError(ctx, errorDetail);
}