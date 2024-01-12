/*
 * Copyright (c) 2024, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.xlibb.schemaregistry.utils;

import graphql.language.ArrayValue;
import graphql.language.Directive;
import graphql.language.DirectiveDefinition;
import graphql.language.InputValueDefinition;
import graphql.language.ListType;
import graphql.language.NonNullType;
import graphql.language.SchemaExtensionDefinition;
import graphql.language.StringValue;
import graphql.language.Type;
import graphql.language.TypeName;
import graphql.schema.idl.ScalarInfo;
import graphql.schema.idl.SchemaParser;
import graphql.schema.idl.TypeDefinitionRegistry;

import java.util.List;

public class FederationUtils {
    private static final SchemaParser parser = new SchemaParser();
    private static final String FEDERATION_REQUIRED_DEFINITIONS = """
        scalar link__Import
        enum link__Purpose {
            SECURITY
            EXECUTION
        }
        type _Service {
            sdl: String!
        }
        extend type Query {
            _service: _Service!
        }
        directive @link(url: String!, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA
            """;
    private static final String FEDERATION_IMPORT_DEFINITIONS = """
        union _Entity

        scalar _Any
        scalar FieldSet
        scalar federation__Scope

        extend type Query {
            _entities(representations: [_Any!]!): [_Entity]!
        }

        directive @external on FIELD_DEFINITION | OBJECT
        directive @requires(fields: FieldSet!) on FIELD_DEFINITION
        directive @provides(fields: FieldSet!) on FIELD_DEFINITION
        directive @key(fields: FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE
        directive @shareable repeatable on OBJECT | FIELD_DEFINITION
        directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR 
                                                    | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
        directive @tag(name: String!) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION
                                                    | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
        directive @override(from: String!) on FIELD_DEFINITION
        directive @composeDirective(name: String!) repeatable on SCHEMA
        directive @interfaceObject on OBJECT
        directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
        directive @requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR 
                                                                                        | ENUM
            """;
    private static TypeDefinitionRegistry requiredFederationDefinitions = parser.parse(FEDERATION_REQUIRED_DEFINITIONS);
    private static TypeDefinitionRegistry possibleFederationDefinitions = parser.parse(FEDERATION_IMPORT_DEFINITIONS);
    
    public static final String LINK_DIRECTIVE = "link";
    public static final String LINK_IMPORT_SCALAR = "link__Import";
    public static final String LINK_DIRECTIVE_IMPORT_FIELD = "import";

    public static TypeDefinitionRegistry getFederationTypes(TypeDefinitionRegistry inputSchemaTypeRegistry) {
        return (new FederationUtils()).getFederationDefinitions(inputSchemaTypeRegistry);
    }

    public TypeDefinitionRegistry getFederationDefinitions(TypeDefinitionRegistry inputSchemaTypeRegistry) {
        TypeDefinitionRegistry outputFederationDefinitions = new TypeDefinitionRegistry();
        List<SchemaExtensionDefinition> schemaExtensions = inputSchemaTypeRegistry.getSchemaExtensionDefinitions();
        outputFederationDefinitions = outputFederationDefinitions.merge(requiredFederationDefinitions);

        for (SchemaExtensionDefinition schemaExtension : schemaExtensions) {
            if (schemaExtension.hasDirective(LINK_DIRECTIVE)) {
                Directive linkDirective = schemaExtension.getDirectivesByName().get(LINK_DIRECTIVE).get(0);
                TypeDefinitionRegistry linkDirectiveImportDefinitions = resolveFederationLinkDirective(linkDirective);
                outputFederationDefinitions = outputFederationDefinitions.merge(linkDirectiveImportDefinitions);
                break;
            }
        }

        return outputFederationDefinitions;
    }

    private TypeDefinitionRegistry resolveFederationLinkDirective(Directive linkDirective) {
        TypeDefinitionRegistry linkDirectiveImportDefinitions = new TypeDefinitionRegistry();
        List<String> importDirectives = ((ArrayValue) linkDirective.getArgument(LINK_DIRECTIVE_IMPORT_FIELD).getValue())
                                            .getValues().stream()
                                            .map(a -> ((StringValue) a).getValue() 
                                            .substring(1)).toList(); // Remove '@' from imports

        for (String importDirectiveName : importDirectives) {
            if (possibleFederationDefinitions.getDirectiveDefinitions().containsKey(importDirectiveName)) {
                DirectiveDefinition importDirectiveDefinition = possibleFederationDefinitions
                                                                .getDirectiveDefinition(importDirectiveName).get();
                for (InputValueDefinition inputValueDefinition : importDirectiveDefinition.getInputValueDefinitions()) {
                    resolveTypeDefinition(linkDirectiveImportDefinitions, inputValueDefinition.getType());
                }
                linkDirectiveImportDefinitions.add(importDirectiveDefinition);
            } else {
                throw new UnsupportedOperationException(String.format(
                        "Directive '%s' is not part of the Federation Specification", 
                        importDirectiveName));
            }
        }
        return linkDirectiveImportDefinitions;
    }

    private <T extends Type<?>> void resolveTypeDefinition(TypeDefinitionRegistry types, T type) {
        if (type.getClass().equals(NonNullType.class)) {
            resolveTypeDefinition(types, ((NonNullType) type).getType());
        } else if (type.getClass().equals(ListType.class)) {
            resolveTypeDefinition(types, ((ListType) type).getType());
        } else if (possibleFederationDefinitions.hasType((TypeName) type)) {
            types.add(possibleFederationDefinitions.getType(((TypeName) type).getName()).get());
        } else if (ScalarInfo.isGraphqlSpecifiedScalar(((TypeName) type).getName())) {
            return; 
        } else {
            throw new UnsupportedOperationException(
                String.format("Type '%s' is not part of the GraphQL or Federation Specifications", 
                                ((TypeName) type).getName())
            );
        }
    }
}
