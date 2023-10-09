package io.xlibb.schemaregistry.utils;

import graphql.schema.Coercing;
import graphql.schema.GraphQLScalarType;
import graphql.schema.idl.MockedWiringFactory;
import graphql.schema.idl.ScalarWiringEnvironment;

public class ParserWiringFactory extends MockedWiringFactory {

    @Override
    public GraphQLScalarType getScalar(ScalarWiringEnvironment environment) {
        // Override Mock wiring to disable Scalar resolving
        return GraphQLScalarType.newScalar()
                .name(environment.getScalarTypeDefinition().getName())
                .coercing(new Coercing<Object, Object>() {
                    @Override
                    public Object parseLiteral(Object input) {
                        return input;
                    }
                })
                .build();
    }
    
}
