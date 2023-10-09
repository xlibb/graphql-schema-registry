package io.xlibb.schemaregistry;

import graphql.language.ArrayValue;
import graphql.language.BooleanValue;
import graphql.language.DirectiveDefinition;
import graphql.language.DirectiveLocation;
import graphql.language.EnumValue;
import graphql.language.FloatValue;
import graphql.language.IntValue;
import graphql.language.NullValue;
import graphql.language.StringValue;
import graphql.language.Value;
import graphql.schema.GraphQLAppliedDirective;
import graphql.schema.GraphQLAppliedDirectiveArgument;
import graphql.schema.GraphQLArgument;
import graphql.schema.GraphQLDirective;
import graphql.schema.GraphQLEnumType;
import graphql.schema.GraphQLEnumValueDefinition;
import graphql.schema.GraphQLFieldDefinition;
import graphql.schema.GraphQLInputObjectField;
import graphql.schema.GraphQLInputObjectType;
import graphql.schema.GraphQLInputValueDefinition;
import graphql.schema.GraphQLInterfaceType;
import graphql.schema.GraphQLList;
import graphql.schema.GraphQLModifiedType;
import graphql.schema.GraphQLNamedOutputType;
import graphql.schema.GraphQLNamedType;
import graphql.schema.GraphQLNonNull;
import graphql.schema.GraphQLObjectType;
import graphql.schema.GraphQLScalarType;
import graphql.schema.GraphQLSchema;
import graphql.schema.GraphQLType;
import graphql.schema.GraphQLUnionType;
import graphql.schema.idl.RuntimeWiring;
import graphql.schema.idl.SchemaGenerator;
import graphql.schema.idl.SchemaParser;
import graphql.schema.idl.TypeDefinitionRegistry;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.internal.types.BAnyType;
import io.xlibb.schemaregistry.utils.FederationUtils;
import io.xlibb.schemaregistry.utils.ModuleUtils;
import io.xlibb.schemaregistry.utils.ParserUtils;
import io.xlibb.schemaregistry.utils.ParserWiringFactory;
import io.xlibb.schemaregistry.utils.TypeKind;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Parser {
    
    private GraphQLSchema schema;
    private Map<String, BMap<BString, Object>> types;
    private Map<String, BMap<BString, Object>> directives;
    private SchemaParser parser;
    
    // TODO: Parser Modes instead of boolean
    public Parser(BString schemaSdl, boolean isSubgraph) {
        types = new HashMap<>();
        directives = new HashMap<>();
        parser = new SchemaParser();
        TypeDefinitionRegistry schemaDefinitions = parser.parse(schemaSdl.getValue());
        if (isSubgraph) {
            TypeDefinitionRegistry federationDefinitions = FederationUtils.getFederationTypes(schemaDefinitions);
            schemaDefinitions = schemaDefinitions.merge(federationDefinitions);
        }
        RuntimeWiring wiring = RuntimeWiring.newRuntimeWiring().wiringFactory(new ParserWiringFactory()).build();
        schema = (new SchemaGenerator()).makeExecutableSchema(schemaDefinitions, wiring);
    }

    public BMap<BString, Object> parse() {
        addTypesShallow();
        addDirectives();
        addTypesDeep();
        addRootOperationTypes();
        return generateSchemaRecord();
    }

    private void addRootOperationTypes() {
        // TODO: Check union _Entity
        // TODO: Add root operation types
        // TODO: Map exceptions to Ballerina Errors
        // TODO: Add code-style to vscode
    }

    private void addTypesShallow() {
        for (GraphQLNamedType graphQLType : schema.getTypeMap().values()) {
            BMap<BString, Object> typeRecord = ParserUtils.createRecord(ParserUtils.TYPE_RECORD);
            // TODO: extract all the put methods to a function
            typeRecord.put(
                ParserUtils.KIND_FIELD,
                StringUtils.fromString(ParserUtils.getTypeKindFromType(graphQLType).toString())
            );
            typeRecord.put(
                ParserUtils.NAME_FIELD,
                StringUtils.fromString(graphQLType.getName())
            );
            typeRecord.put(
                ParserUtils.DESCRIPTION_FIELD,
                StringUtils.fromString(graphQLType.getDescription())
            );
            types.put(graphQLType.getName(), typeRecord);
        }
    }

    private void addDirectives() {
        for (GraphQLDirective directive : schema.getDirectives()) {
            BMap<BString, Object> directiveRecord = ParserUtils.createRecord(ParserUtils.DIRECTIVE_RECORD);
            directiveRecord.put(
                ParserUtils.NAME_FIELD,
                StringUtils.fromString(directive.getName())
            );
            directiveRecord.put(
                ParserUtils.DESCRIPTION_FIELD,
                StringUtils.fromString(directive.getDescription())
            );
            directiveRecord.put(
                ParserUtils.ARGS_FIELD,
                getInputValuesAsBMap(directive.getArguments())
            );

            DirectiveDefinition directiveDefinition = directive.getDefinition();
            if (directiveDefinition != null) {
                directiveRecord.put(
                    ParserUtils.DIRECTIVE_LOCATIONS_FIELD,
                    getDirectiveLocationsAsBArray(directiveDefinition.getDirectiveLocations())
                );
                directiveRecord.put(
                    ParserUtils.DIRECTIVE_IS_REPEATABLE_FIELD,
                    directiveDefinition.isRepeatable()
                );
            }
            directives.put(directive.getName(), directiveRecord);
        }
    }

    private void addTypesDeep() {
        for (GraphQLNamedType graphQLType : schema.getTypeMap().values()) {

            BMap<BString, Object> typeRecord = types.get(graphQLType.getName());
            TypeKind graphQLTypeKind = ParserUtils.getTypeKindFromType(graphQLType);

            // TODO: Check switch statement
            if (graphQLTypeKind == TypeKind.OBJECT) {
                 populateObjectTypeRecord(typeRecord, (GraphQLObjectType) graphQLType);
            } else if (graphQLTypeKind == TypeKind.ENUM) {
                populateEnumTypeRecord(typeRecord, (GraphQLEnumType) graphQLType);
            } else if (graphQLTypeKind == TypeKind.UNION) {
                populateUnionTypeRecord(typeRecord, (GraphQLUnionType) graphQLType);
            } else if (graphQLTypeKind == TypeKind.INPUT_OBJECT) {
                populateInputTypeRecord(typeRecord, (GraphQLInputObjectType) graphQLType);
            } else if (graphQLTypeKind == TypeKind.INTERFACE) {
                populateInterfaceTypeRecord(typeRecord, (GraphQLInterfaceType) graphQLType);
            } else if (graphQLTypeKind == TypeKind.SCALAR) {
                populateScalarTypeRecord(typeRecord, (GraphQLScalarType) graphQLType);
            }
        }
    }

    private void populateScalarTypeRecord(BMap<BString, Object> typeRecord, GraphQLScalarType scalarType) {
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                    getAppliedDirectivesAsBMap(scalarType.getAppliedDirectives()));
    }

    private void populateInterfaceTypeRecord(BMap<BString, Object> typeRecord, GraphQLInterfaceType interfaceType) {
        typeRecord.put(ParserUtils.FIELDS_FIELD, getFieldsAsBMap(interfaceType.getFields()));
        typeRecord.put(ParserUtils.INTERFACES_FIELD, getInterfacesBArray(interfaceType.getInterfaces()));
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                    getAppliedDirectivesAsBMap(interfaceType.getAppliedDirectives()));
        // TODO: Interface possible types
    }

    private void populateInputTypeRecord(BMap<BString, Object> typeRecord, GraphQLInputObjectType inputObjectType) {
        typeRecord.put(ParserUtils.INPUT_VALUES_FIELD, getInputValuesAsBMap(inputObjectType.getFields()));
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                    getAppliedDirectivesAsBMap(inputObjectType.getAppliedDirectives()));
    }

    private void populateUnionTypeRecord(BMap<BString, Object> typeRecord, GraphQLUnionType unionType) {
        typeRecord.put(ParserUtils.POSSIBLE_TYPES_FIELD, getPossibleTypesAsBArray(unionType.getTypes()));
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                    getAppliedDirectivesAsBMap(unionType.getAppliedDirectives()));
    }

    private void populateObjectTypeRecord(BMap<BString, Object> typeRecord, GraphQLObjectType objectType) {
        typeRecord.put(ParserUtils.FIELDS_FIELD, getFieldsAsBMap(objectType.getFields()));
        typeRecord.put(ParserUtils.INTERFACES_FIELD, getInterfacesBArray(objectType.getInterfaces()));
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                        getAppliedDirectivesAsBMap(objectType.getAppliedDirectives()));
    }

    private void populateEnumTypeRecord(BMap<BString, Object> typeRecord, GraphQLEnumType enumType) {
        typeRecord.put(ParserUtils.ENUM_FIELD, getEnumValuesAsBArray(enumType.getValues()));
        typeRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                                                    getAppliedDirectivesAsBMap(enumType.getAppliedDirectives()));
    }

    private BArray getInterfacesBArray(List<GraphQLNamedOutputType> interfaces) {
        BArray interfacesBArray = ParserUtils.createBArrayFromRecord(
                                    ParserUtils.createRecord(ParserUtils.TYPE_RECORD));
        for (GraphQLNamedOutputType graphQLType : interfaces) {
            interfacesBArray.append(getTypeAsRecord(graphQLType));
        }
        return interfacesBArray;
    }

    private BMap<BString, Object> getInputValuesAsBMap(List<? extends GraphQLInputValueDefinition> fields) {
        BMap<BString, Object> inputValueRecordsMap = ValueCreator.createMapValue();
        for (GraphQLInputValueDefinition inputValueDefinition : fields) {
            BMap<BString, Object> inputValueRecord = ParserUtils.createRecord(ParserUtils.INPUT_VALUE_RECORD);
            inputValueRecord.put(
                ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                getAppliedDirectivesAsBMap(inputValueDefinition.getAppliedDirectives())
            );
            inputValueRecord.put(
                ParserUtils.NAME_FIELD,
                StringUtils.fromString(inputValueDefinition.getName())
            );
            inputValueRecord.put(
                ParserUtils.DESCRIPTION_FIELD,
                StringUtils.fromString(inputValueDefinition.getDescription())
            );
            inputValueRecord.put(
                ParserUtils.TYPE_FIELD,
                getTypeAsRecord(inputValueDefinition.getType())
            );
            inputValueRecord.put(
                ParserUtils.DEFAULT_VALUE_FIELD,
                getInputDefaultAsBType(inputValueDefinition)
            );

            inputValueRecordsMap.put(
                StringUtils.fromString(inputValueDefinition.getName()),
                inputValueRecord
            );
        }
        return inputValueRecordsMap;
    }

    private Object getInputDefaultAsBType(GraphQLInputValueDefinition input) {
        Object defaultValue = null;
        if (input.getClass().equals(GraphQLArgument.class) 
                && ((GraphQLArgument) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLArgument) input).getArgumentDefaultValue().getValue();

        } else if (input.getClass().equals(GraphQLInputObjectField.class)
                && ((GraphQLInputObjectField) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLInputObjectField) input).getInputFieldDefaultValue().getValue();
        }
        return defaultValue == null ? null : getValueAsBType(defaultValue);
    }

    private Object getValueAsBType(Object valueObject) {
        Class<?> valueClass = valueObject.getClass();
        if (valueClass.equals(NullValue.class)) {
            return null;
        } else if (valueClass.equals(FloatValue.class)) {
            return ((FloatValue) valueObject).getValue().doubleValue();
        } else if (valueClass.equals(IntValue.class)) {
            return ((IntValue) valueObject).getValue().intValue();
        } else if (valueClass.equals(StringValue.class)) {
            return StringUtils.fromString(((StringValue) valueObject).getValue());
        } else if (valueClass.equals(BooleanValue.class)) {
            return ((BooleanValue) valueObject).isValue();
        } else if (valueClass.equals(EnumValue.class)) {
            return StringUtils.fromString(((EnumValue) valueObject).getName());
        } else if (valueClass.equals(ArrayValue.class)) {
            ArrayType arrayType = TypeCreator.createArrayType(new BAnyType("any", ModuleUtils.getModule(), false));
            BArray bArray = ValueCreator.createArrayValue(arrayType);
            for (Value<?> value : ((ArrayValue) valueObject).getValues()) {
                bArray.append(getValueAsBType(value));
            }
            return bArray;
        } else {
            return null;
        }
    }

    private Object getAppliedDirectivesAsBMap(List<GraphQLAppliedDirective> appliedDirectives) {
        BMap<BString, Object> appliedDirectivesBMap = ValueCreator.createMapValue();
        for (GraphQLAppliedDirective directive : appliedDirectives) {
            BMap<BString, Object> appliedDirectiveRecord = ParserUtils.createRecord(
                                                                                ParserUtils.APPLIED_DIRECTIVE_RECORD);
            appliedDirectiveRecord.put(ParserUtils.ARGS_FIELD,  
                                                        getAppliedDirectiveArgumentsAsBMap(directive.getArguments()));
            appliedDirectiveRecord.put(ParserUtils.DEFINITION_FIELD, directives.get(directive.getName()));

            appliedDirectivesBMap.put(StringUtils.fromString(directive.getName()), appliedDirectiveRecord);
        }
        return appliedDirectivesBMap;
    }

    private Object getAppliedDirectiveArgumentsAsBMap(List<GraphQLAppliedDirectiveArgument> arguments) {
        BMap<BString, Object> argumentsBMap = ValueCreator.createMapValue();
        for (GraphQLAppliedDirectiveArgument argument : arguments) {
            BMap<BString, Object> appliedArgumentInputValueRecord = ParserUtils.createRecord(
                                                                    ParserUtils.APPLIED_DIRECTIVE_INPUT_VALUE_RECORD);
            appliedArgumentInputValueRecord.put(ParserUtils.DEFINITION_FIELD, getTypeAsRecord(argument.getType()));
            appliedArgumentInputValueRecord.put(ParserUtils.VALUE_FIELD, getValueAsBType(argument.getArgumentValue()));

            argumentsBMap.put(StringUtils.fromString(argument.getName()), appliedArgumentInputValueRecord);
        }
        return argumentsBMap;
    }

    private BArray getPossibleTypesAsBArray(List<GraphQLNamedOutputType> namedTypes) {
        BArray possibleTypesBArray = ParserUtils.createBArrayFromRecord(
                                    ParserUtils.createRecord(ParserUtils.TYPE_RECORD));
        for (GraphQLNamedOutputType graphQLNamedOutputType : namedTypes) {
            possibleTypesBArray.append(getTypeAsRecord(graphQLNamedOutputType));
        }
        return possibleTypesBArray;
    }

    private BArray getEnumValuesAsBArray(List<GraphQLEnumValueDefinition> enumValueDefinitions) {
        BArray enumValuesBArray = ParserUtils.createBArrayFromRecord(
                                    ParserUtils.createRecord(ParserUtils.ENUM_VALUE_RECORD));
        for (GraphQLEnumValueDefinition enumValueDefinition : enumValueDefinitions) {
            BMap<BString, Object> enumValueRecord = ParserUtils.createRecord(ParserUtils.ENUM_VALUE_RECORD);
            enumValueRecord.put(
                ParserUtils.APPLIED_DIRECTIVES_FIELD,  
                getAppliedDirectivesAsBMap(enumValueDefinition.getAppliedDirectives())
            );
            enumValueRecord.put(
                ParserUtils.NAME_FIELD,
                StringUtils.fromString(enumValueDefinition.getName())
            );
            enumValueRecord.put(
                ParserUtils.DESCRIPTION_FIELD,
                StringUtils.fromString(enumValueDefinition.getDescription())
            );
            enumValueRecord.put(
                ParserUtils.IS_DEPRECATED_FIELD,
                enumValueDefinition.isDeprecated()
            );
            enumValueRecord.put(
                ParserUtils.DEPRECATION_REASON_FIELD,
                enumValueDefinition.getDeprecationReason()
            );

            enumValuesBArray.append(enumValueRecord);
        }

        return enumValuesBArray;
    }

    private BArray getDirectiveLocationsAsBArray(List<DirectiveLocation> locations) {
        BString[] locationsArray = new BString[locations.size()];
        for (int i = 0; i < locations.size(); i++) {
            locationsArray[i] = StringUtils.fromString(locations.get(i).getName());
        }
        return ValueCreator.createArrayValue(locationsArray);
    }

    private BMap<BString, Object> getFieldsAsBMap(List<GraphQLFieldDefinition> fields) {
        BMap<BString, Object> fieldsBArray = ValueCreator.createMapValue();
        for (GraphQLFieldDefinition fieldDefinition : fields) {
            BMap<BString, Object> fieldRecord = ParserUtils.createRecord(ParserUtils.FIELD_RECORD);
            fieldRecord.put(ParserUtils.NAME_FIELD, StringUtils.fromString(fieldDefinition.getName()));
            fieldRecord.put(ParserUtils.TYPE_FIELD, getTypeAsRecord(fieldDefinition.getType()));
            fieldRecord.put(ParserUtils.ARGS_FIELD, getInputValuesAsBMap(fieldDefinition.getArguments()));
            fieldRecord.put(ParserUtils.APPLIED_DIRECTIVES_FIELD,
                                                    getAppliedDirectivesAsBMap(fieldDefinition.getAppliedDirectives()));
            fieldsBArray.put(StringUtils.fromString(fieldDefinition.getName()), fieldRecord);
        }
        return fieldsBArray;
    }

    private BMap<BString, Object> getTypeAsRecord(GraphQLType type) {
        BMap<BString, Object> typeRecord;
        if (type.getClass().equals(GraphQLList.class) || type.getClass().equals(GraphQLNonNull.class)) {
            typeRecord = ParserUtils.createRecord(ParserUtils.TYPE_RECORD);
            typeRecord.put(
                ParserUtils.OF_TYPE_FIELD,
                getTypeAsRecord(((GraphQLModifiedType) type).getWrappedType())
            );
            typeRecord.put(
                ParserUtils.KIND_FIELD,
                StringUtils.fromString(ParserUtils.getTypeKindFromType(type).toString())
            );
        } else {
            typeRecord = types.get(((GraphQLNamedType) type).getName());
        }
        return typeRecord;
    }

    private BMap<BString, Object> generateSchemaRecord() {
        BMap<BString, Object> graphQLSchemaRecord = ParserUtils.createRecord(ParserUtils.SCHEMA_RECORD);
        BMap<BString, Object> schemaRecordTypes = ValueCreator.createMapValue();
        BMap<BString, Object> schemaDirectives = ValueCreator.createMapValue();
        for (Map.Entry<String, BMap<BString, Object>> type : types.entrySet()) {
            ParserUtils.addValueToRecordField(
                schemaRecordTypes,
                StringUtils.fromString(type.getKey()),
                type.getValue()
            );
        }
        for (Map.Entry<String, BMap<BString, Object>> directive : directives.entrySet()) {
            ParserUtils.addValueToRecordField(
                schemaDirectives,
                StringUtils.fromString(directive.getKey()), 
                directive.getValue()
            );
        }
        ParserUtils.addValueToRecordField(graphQLSchemaRecord, ParserUtils.TYPES_FIELD, schemaRecordTypes);
        ParserUtils.addValueToRecordField(graphQLSchemaRecord, ParserUtils.DIRECTIVES_FIELD, schemaDirectives);
        return graphQLSchemaRecord;
    }

}
