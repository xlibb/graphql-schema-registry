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

import graphql.schema.GraphQLType;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.types.MapType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;

public class ParserUtils {

    // Ballerina Types
    public static final String ANYDATA = "anydata";

    // Types of the GraphQL Introspection Type System
    public static final String SCHEMA_RECORD = "__Schema";
    public static final String TYPE_RECORD = "__Type";
    public static final String DIRECTIVE_RECORD = "__Directive";
    public static final String DIRECTIVE_LOCATION_RECORD = "__DirectiveLocation";
    public static final String FIELD_RECORD = "__Field";
    public static final String INPUT_VALUE_RECORD = "__InputValue";
    public static final String ENUM_VALUE_RECORD = "__EnumValue";
    public static final String APPLIED_DIRECTIVE_RECORD = "__AppliedDirective";
    public static final String APPLIED_DIRECTIVE_INPUT_VALUE_RECORD = "__AppliedDirectiveInputValue";

    // GraphQL Type names of the Root Operations
    public static final String QUERY_TYPE_NAME = "Query";
    public static final String MUTATION_TYPE_NAME = "Mutation";
    public static final String SUBSCRIPTION_TYPE_NAME = "Subscription";

    // Field names of the GraphQL Introspection Type System
    public static final BString NAME_FIELD = StringUtils.fromString("name");
    public static final BString ROOT_QUERY_FIELD = StringUtils.fromString("queryType");
    public static final BString ROOT_MUTATION_FIELD = StringUtils.fromString("mutationType");
    public static final BString ROOT_SUBSCRIPTION_FIELD = StringUtils.fromString("subscriptionType");
    public static final BString KIND_FIELD = StringUtils.fromString("kind");
    public static final BString TYPE_FIELD = StringUtils.fromString("type");
    public static final BString OF_TYPE_FIELD = StringUtils.fromString("ofType");
    public static final BString FIELDS_FIELD = StringUtils.fromString("fields");
    public static final BString DESCRIPTION_FIELD = StringUtils.fromString("description");
    public static final BString ENUM_FIELD = StringUtils.fromString("enumValues");
    public static final BString IS_DEPRECATED_FIELD = StringUtils.fromString("isDeprecated");
    public static final BString DEPRECATION_REASON_FIELD = StringUtils.fromString("deprecationReason");
    public static final BString POSSIBLE_TYPES_FIELD = StringUtils.fromString("possibleTypes");
    public static final BString INPUT_VALUES_FIELD = StringUtils.fromString("inputFields");
    public static final BString DEFAULT_VALUE_FIELD = StringUtils.fromString("defaultValue");
    public static final BString ARGS_FIELD = StringUtils.fromString("args");
    public static final BString INTERFACES_FIELD = StringUtils.fromString("interfaces");
    public static final BString DIRECTIVES_FIELD = StringUtils.fromString("directives");
    public static final BString TYPES_FIELD = StringUtils.fromString("types");
    public static final BString DIRECTIVE_LOCATIONS_FIELD = StringUtils.fromString("locations");
    public static final BString DIRECTIVE_IS_REPEATABLE_FIELD = StringUtils.fromString("isRepeatable");
    public static final BString APPLIED_DIRECTIVES_FIELD = StringUtils.fromString("appliedDirectives");
    public static final BString DEFINITION_FIELD = StringUtils.fromString("definition");
    public static final BString VALUE_FIELD = StringUtils.fromString("value");

    public enum ParsingMode {
        SCHEMA,
        SUBGRAPH_SCHEMA,
        SUPERGRAPH_SCHEMA
    }

    public static BMap<BString, Object> createRecord(String type) {
        return ValueCreator.createRecordValue(ModuleUtils.getModule(), type);
    }

    public static BMap<BString, Object> createRecordMap(String type) {
        MapType mapType = TypeCreator.createMapType(
            TypeCreator.createRecordType(type, ModuleUtils.getModule(), 0, true, 6)
        );
        return ValueCreator.createMapValue(mapType);
    }

    public static BArray createBArrayFromRecord(BMap<BString, Object> record) {
        ArrayType recordType = TypeCreator.createArrayType(record.getType());
        BArray bArray = ValueCreator.createArrayValue(recordType);
        return bArray;
    }

    public static TypeKind getTypeKindFromType(GraphQLType type) {
        return getGraphQLTypeKindFromString(type.getClass().getSimpleName().toString());
    }

    public static TypeKind getGraphQLTypeKindFromString(String typeName) {
        switch (typeName) {
            case "GraphQLObjectType":
                return TypeKind.OBJECT;
            case "GraphQLScalarType":
                return TypeKind.SCALAR;
            case "GraphQLEnumType":
                return TypeKind.ENUM;
            case "GraphQLNonNull":
                return TypeKind.NON_NULL;
            case "GraphQLList":
                return TypeKind.LIST;
            case "GraphQLUnionType":
                return TypeKind.UNION;
            case "GraphQLInputObjectType":
                return TypeKind.INPUT_OBJECT;
            case "GraphQLInterfaceType":
                return TypeKind.INTERFACE;
            default:
                return null;
        }
    }

    public static void addValueToRecordField(BMap<BString, Object> record, BString field, Object value) {
        record.put(field, value);
    }
}
