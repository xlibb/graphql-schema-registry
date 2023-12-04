import ballerina/graphql;
isolated function returnErrors(graphql:Context ctx, graphql:Field 'field, string message, error[] errors) {
    graphql:ErrorDetail errorDetail = {
        message: message,
        locations: ['field.getLocation()],
        path: 'field.getPath(),
        extensions: {
            errors: errors.map(e => e.message())
        }
    };
    graphql:__addError(ctx, errorDetail);
}