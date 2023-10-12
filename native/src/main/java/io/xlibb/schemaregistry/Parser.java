package io.xlibb.schemaregistry;

import graphql.introspection.Introspection.DirectiveLocation;
import graphql.language.ArrayValue;
import graphql.language.BooleanValue;
import graphql.language.DirectiveDefinition;
import graphql.language.EnumValue;
import graphql.language.FloatValue;
import graphql.language.IntValue;
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
import io.xlibb.schemaregistry.utils.ParserUtils.ParsingMode;
import io.xlibb.schemaregistry.utils.ParserWiringFactory;
import io.xlibb.schemaregistry.utils.TypeKind;

import java.util.EnumSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static io.xlibb.schemaregistry.utils.ParserUtils.ARGS_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.APPLIED_DIRECTIVES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.APPLIED_DIRECTIVE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.APPLIED_DIRECTIVE_INPUT_VALUE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.ANYDATA;
import static io.xlibb.schemaregistry.utils.ParserUtils.DEFAULT_VALUE_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DEFINITION_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DESCRIPTION_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DEPRECATION_REASON_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DIRECTIVE_IS_REPEATABLE_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DIRECTIVE_LOCATIONS_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DIRECTIVE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.DIRECTIVES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.ENUM_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.ENUM_VALUE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.FIELDS_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.FIELD_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.INTERFACES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.INPUT_VALUES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.INPUT_VALUE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.IS_DEPRECATED_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.KIND_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.MUTATION_TYPE_NAME;
import static io.xlibb.schemaregistry.utils.ParserUtils.NAME_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.OF_TYPE_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.POSSIBLE_TYPES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.QUERY_TYPE_NAME;
import static io.xlibb.schemaregistry.utils.ParserUtils.ROOT_MUTATION_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.ROOT_QUERY_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.ROOT_SUBSCRIPTION_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.SCHEMA_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.SUBSCRIPTION_TYPE_NAME;
import static io.xlibb.schemaregistry.utils.ParserUtils.TYPE_RECORD;
import static io.xlibb.schemaregistry.utils.ParserUtils.TYPES_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.TYPE_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.VALUE_FIELD;
import static io.xlibb.schemaregistry.utils.ParserUtils.addValueToRecordField;
import static io.xlibb.schemaregistry.utils.ParserUtils.createRecord;
import static io.xlibb.schemaregistry.utils.ParserUtils.createBArrayFromRecord;
import static io.xlibb.schemaregistry.utils.ParserUtils.getTypeKindFromType;

public class Parser {

    private final GraphQLSchema schema;
    private final Map<String, BMap<BString, Object>> types;
    private final Map<String, BMap<BString, Object>> directives;

    public Parser(BString schemaSdl, BString modeStr) {

        types = new HashMap<>();
        directives = new HashMap<>();
        SchemaParser parser = new SchemaParser();

        TypeDefinitionRegistry schemaDefinitions = parser.parse(schemaSdl.getValue());
        switch (ParsingMode.valueOf(modeStr.getValue())) {
            case SUBGRAPH_SCHEMA -> {
                TypeDefinitionRegistry federationDefinitions = FederationUtils.getFederationTypes(schemaDefinitions);
                schemaDefinitions = schemaDefinitions.merge(federationDefinitions);
            }
            case SUPERGRAPH_SCHEMA -> {
            }
            case SCHEMA -> {
            }
        }

        RuntimeWiring wiring = RuntimeWiring.newRuntimeWiring().wiringFactory(new ParserWiringFactory()).build();
        schema = (new SchemaGenerator()).makeExecutableSchema(schemaDefinitions, wiring);
    }

    public BMap<BString, Object> parse() {

        addTypesShallow();
        addDirectives();
        addTypesDeep();
        return generateSchemaRecord();
    }

    private void addTypesShallow() {

        for (GraphQLNamedType graphQLType : schema.getTypeMap().values()) {
            if (!isIntrospectionType(graphQLType)) {
                BMap<BString, Object> typeRecord = createRecord(TYPE_RECORD);
                addValueToRecordField(
                        typeRecord,
                        KIND_FIELD,
                        StringUtils.fromString(getTypeKindFromType(graphQLType).toString())
                                    );
                addValueToRecordField(
                        typeRecord,
                        NAME_FIELD,
                        StringUtils.fromString(graphQLType.getName())
                                    );
                addValueToRecordField(
                        typeRecord,
                        DESCRIPTION_FIELD,
                        StringUtils.fromString(graphQLType.getDescription())
                                    );
                types.put(graphQLType.getName(), typeRecord);
            }
        }
    }

    private void addDirectives() {

        for (GraphQLDirective directive : schema.getDirectives()) {
            BMap<BString, Object> directiveRecord = createRecord(DIRECTIVE_RECORD);
            addValueToRecordField(
                    directiveRecord,
                    NAME_FIELD,
                    StringUtils.fromString(directive.getName())
                                 );
            addValueToRecordField(
                    directiveRecord,
                    DESCRIPTION_FIELD,
                    StringUtils.fromString(directive.getDescription())
                                 );
            addValueToRecordField(
                    directiveRecord,
                    ARGS_FIELD,
                    getInputValuesAsBMap(directive.getArguments())
                                 );
            addValueToRecordField(
                    directiveRecord,
                    DIRECTIVE_LOCATIONS_FIELD,
                    getDirectiveLocationsAsBArray(directive.validLocations())
                                    );

            DirectiveDefinition directiveDefinition = directive.getDefinition();
            if (directiveDefinition != null) {
                addValueToRecordField(
                        directiveRecord,
                        DIRECTIVE_IS_REPEATABLE_FIELD,
                        directiveDefinition.isRepeatable()
                                     );
            }
            directives.put(directive.getName(), directiveRecord);
        }
    }

    private void addTypesDeep() {

        for (GraphQLNamedType graphQLType : schema.getTypeMap().values()) {

            BMap<BString, Object> typeRecord = types.get(graphQLType.getName());
            if (typeRecord != null) {
                TypeKind graphQLTypeKind = getTypeKindFromType(graphQLType);

                switch (graphQLTypeKind) {
                    case OBJECT -> populateObjectTypeRecord(typeRecord, (GraphQLObjectType) graphQLType);
                    case ENUM -> populateEnumTypeRecord(typeRecord, (GraphQLEnumType) graphQLType);
                    case UNION -> populateUnionTypeRecord(typeRecord, (GraphQLUnionType) graphQLType);
                    case INPUT_OBJECT -> populateInputTypeRecord(typeRecord, (GraphQLInputObjectType) graphQLType);
                    case INTERFACE -> populateInterfaceTypeRecord(typeRecord, (GraphQLInterfaceType) graphQLType);
                    case SCALAR -> populateScalarTypeRecord(typeRecord, (GraphQLScalarType) graphQLType);
                    default -> {
                    }
                }
            }
        }
    }

    private void populateScalarTypeRecord(BMap<BString, Object> typeRecord, GraphQLScalarType scalarType) {

        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(scalarType.getAppliedDirectives())
                             );
    }

    private void populateInterfaceTypeRecord(BMap<BString, Object> typeRecord, GraphQLInterfaceType interfaceType) {

        addValueToRecordField(typeRecord, FIELDS_FIELD, getFieldsAsBMap(interfaceType.getFields()));
        addValueToRecordField(typeRecord, INTERFACES_FIELD, getInterfacesBArray(interfaceType.getInterfaces()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(interfaceType.getAppliedDirectives())
                             );
        addValueToRecordField(
                typeRecord,
                POSSIBLE_TYPES_FIELD,
                createBArrayFromRecord(createRecord(TYPE_RECORD)) // TODO: Get possible types of the interface
                             );
    }

    private void populateInputTypeRecord(BMap<BString, Object> typeRecord, GraphQLInputObjectType inputObjectType) {

        addValueToRecordField(
                typeRecord,
                INPUT_VALUES_FIELD,
                getInputValuesAsBMap(inputObjectType.getFields())
                             );
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(inputObjectType.getAppliedDirectives())
                             );
    }

    private void populateUnionTypeRecord(BMap<BString, Object> typeRecord, GraphQLUnionType unionType) {

        addValueToRecordField(typeRecord, POSSIBLE_TYPES_FIELD, getPossibleTypesAsBArray(unionType.getTypes()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(unionType.getAppliedDirectives())
                             );
    }

    private void populateObjectTypeRecord(BMap<BString, Object> typeRecord, GraphQLObjectType objectType) {

        addValueToRecordField(typeRecord, FIELDS_FIELD, getFieldsAsBMap(objectType.getFields()));
        addValueToRecordField(typeRecord, INTERFACES_FIELD, getInterfacesBArray(objectType.getInterfaces()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(objectType.getAppliedDirectives())
                             );
    }

    private void populateEnumTypeRecord(BMap<BString, Object> typeRecord, GraphQLEnumType enumType) {

        addValueToRecordField(typeRecord, ENUM_FIELD, getEnumValuesAsBArray(enumType.getValues()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBMap(enumType.getAppliedDirectives())
                             );
    }

    private BArray getInterfacesBArray(List<GraphQLNamedOutputType> interfaces) {

        BArray interfacesBArray = createBArrayFromRecord(createRecord(TYPE_RECORD));
        for (GraphQLNamedOutputType graphQLType : interfaces) {
            interfacesBArray.append(getTypeAsRecord(graphQLType));
        }
        return interfacesBArray;
    }

    private BMap<BString, Object> getInputValuesAsBMap(List<? extends GraphQLInputValueDefinition> fields) {

        BMap<BString, Object> inputValueRecordsMap = ValueCreator.createMapValue();
        for (GraphQLInputValueDefinition inputValueDefinition : fields) {
            BMap<BString, Object> inputValueRecord = createRecord(INPUT_VALUE_RECORD);
            addValueToRecordField(
                    inputValueRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBMap(inputValueDefinition.getAppliedDirectives())
                                 );
            addValueToRecordField(
                    inputValueRecord,
                    NAME_FIELD,
                    StringUtils.fromString(inputValueDefinition.getName())
                                 );
            addValueToRecordField(
                    inputValueRecord,
                    DESCRIPTION_FIELD,
                    StringUtils.fromString(inputValueDefinition.getDescription())
                                 );
            addValueToRecordField(
                    inputValueRecord,
                    TYPE_FIELD,
                    getTypeAsRecord(inputValueDefinition.getType())
                                 );
            addValueToRecordField(
                    inputValueRecord,
                    DEFAULT_VALUE_FIELD,
                    getInputDefaultAsBType(inputValueDefinition)
                                 );

            addValueToRecordField(
                    inputValueRecordsMap,
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

        if (valueObject instanceof FloatValue) {
            return ((FloatValue) valueObject).getValue().doubleValue();
        } else if (valueObject instanceof IntValue) {
            return ((IntValue) valueObject).getValue().intValue();
        } else if (valueObject instanceof StringValue) {
            return StringUtils.fromString(((StringValue) valueObject).getValue());
        } else if (valueObject instanceof BooleanValue) {
            return ((BooleanValue) valueObject).isValue();
        } else if (valueObject instanceof EnumValue) {
            return StringUtils.fromString(((EnumValue) valueObject).getName());
        } else if (valueObject instanceof ArrayValue) {
            ArrayType arrayType = TypeCreator.createArrayType(new BAnyType(ANYDATA, ModuleUtils.getModule(), false));
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
            BMap<BString, Object> appliedDirectiveRecord = createRecord(APPLIED_DIRECTIVE_RECORD);
            addValueToRecordField(
                    appliedDirectiveRecord,
                    ARGS_FIELD,
                    getAppliedDirectiveArgumentsAsBMap(directive.getArguments())
                                 );
            addValueToRecordField(
                    appliedDirectiveRecord,
                    DEFINITION_FIELD,
                    directives.get(directive.getName())
                                 );

            addValueToRecordField(
                    appliedDirectivesBMap,
                    StringUtils.fromString(directive.getName()),
                    appliedDirectiveRecord
                                 );
        }
        return appliedDirectivesBMap;
    }

    private Object getAppliedDirectiveArgumentsAsBMap(List<GraphQLAppliedDirectiveArgument> arguments) {

        BMap<BString, Object> argumentsBMap = ValueCreator.createMapValue();
        for (GraphQLAppliedDirectiveArgument argument : arguments) {
            BMap<BString, Object> appliedArgumentInputValueRecord = createRecord(APPLIED_DIRECTIVE_INPUT_VALUE_RECORD);
            addValueToRecordField(
                    appliedArgumentInputValueRecord,
                    DEFINITION_FIELD,
                    getTypeAsRecord(argument.getType())
                                 );
            addValueToRecordField(
                    appliedArgumentInputValueRecord,
                    VALUE_FIELD,
                    getValueAsBType(argument.getArgumentValue().getValue())
                                 );

            addValueToRecordField(
                    argumentsBMap,
                    StringUtils.fromString(argument.getName()),
                    appliedArgumentInputValueRecord
                                 );
        }
        return argumentsBMap;
    }

    private BArray getPossibleTypesAsBArray(List<GraphQLNamedOutputType> namedTypes) {

        BArray possibleTypesBArray = createBArrayFromRecord(createRecord(TYPE_RECORD));
        for (GraphQLNamedOutputType graphQLNamedOutputType : namedTypes) {
            possibleTypesBArray.append(getTypeAsRecord(graphQLNamedOutputType));
        }
        return possibleTypesBArray;
    }

    private BArray getEnumValuesAsBArray(List<GraphQLEnumValueDefinition> enumValueDefinitions) {

        BArray enumValuesBArray = createBArrayFromRecord(createRecord(ENUM_VALUE_RECORD));
        for (GraphQLEnumValueDefinition enumValueDefinition : enumValueDefinitions) {
            BMap<BString, Object> enumValueRecord = createRecord(ENUM_VALUE_RECORD);
            addValueToRecordField(
                    enumValueRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBMap(enumValueDefinition.getAppliedDirectives())
                                 );
            addValueToRecordField(
                    enumValueRecord,
                    NAME_FIELD,
                    StringUtils.fromString(enumValueDefinition.getName())
                                 );
            addValueToRecordField(
                    enumValueRecord,
                    DESCRIPTION_FIELD,
                    StringUtils.fromString(enumValueDefinition.getDescription())
                                 );
            addValueToRecordField(
                    enumValueRecord,
                    IS_DEPRECATED_FIELD,
                    enumValueDefinition.isDeprecated()
                                 );
            addValueToRecordField(
                    enumValueRecord,
                    DEPRECATION_REASON_FIELD,
                    StringUtils.fromString(enumValueDefinition.getDeprecationReason())
                                 );

            enumValuesBArray.append(enumValueRecord);
        }

        return enumValuesBArray;
    }

    private BArray getDirectiveLocationsAsBArray(EnumSet<DirectiveLocation> enumSet) {
        List<BString> locationsArray = enumSet.stream().map(t -> StringUtils.fromString(t.name())).toList();
        BString[] locationsBArray = new BString[enumSet.size()];
        locationsArray.toArray(locationsBArray);
        return ValueCreator.createArrayValue(locationsBArray);
    }

    private BMap<BString, Object> getFieldsAsBMap(List<GraphQLFieldDefinition> fields) {

        BMap<BString, Object> fieldsBArray = ValueCreator.createMapValue();
        for (GraphQLFieldDefinition fieldDefinition : fields) {
            BMap<BString, Object> fieldRecord = createRecord(FIELD_RECORD);
            addValueToRecordField(fieldRecord, NAME_FIELD, StringUtils.fromString(fieldDefinition.getName()));
            addValueToRecordField(fieldRecord, TYPE_FIELD, getTypeAsRecord(fieldDefinition.getType()));
            addValueToRecordField(fieldRecord, ARGS_FIELD, getInputValuesAsBMap(fieldDefinition.getArguments()));
            addValueToRecordField(
                    fieldRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBMap(fieldDefinition.getAppliedDirectives())
                                 );
            addValueToRecordField(fieldsBArray, StringUtils.fromString(fieldDefinition.getName()), fieldRecord);
        }
        return fieldsBArray;
    }

    private BMap<BString, Object> getTypeAsRecord(GraphQLType type) {

        BMap<BString, Object> typeRecord;
        if (type.getClass().equals(GraphQLList.class) || type.getClass().equals(GraphQLNonNull.class)) {
            typeRecord = createRecord(TYPE_RECORD);
            addValueToRecordField(
                    typeRecord,
                    OF_TYPE_FIELD,
                    getTypeAsRecord(((GraphQLModifiedType) type).getWrappedType())
                                 );
            addValueToRecordField(
                    typeRecord,
                    KIND_FIELD,
                    StringUtils.fromString(getTypeKindFromType(type).toString())
                                 );
        } else {
            typeRecord = types.get(((GraphQLNamedType) type).getName());
        }
        return typeRecord;
    }

    private boolean isIntrospectionType(GraphQLNamedType graphQLType) {

        return (graphQLType.getName().startsWith("__"));
    }

    private BMap<BString, Object> generateSchemaRecord() {

        BMap<BString, Object> graphQLSchemaRecord = createRecord(SCHEMA_RECORD);
        BMap<BString, Object> schemaRecordTypes = ValueCreator.createMapValue();
        BMap<BString, Object> schemaDirectives = ValueCreator.createMapValue();
        for (Map.Entry<String, BMap<BString, Object>> type : types.entrySet()) {
            addValueToRecordField(
                    schemaRecordTypes,
                    StringUtils.fromString(type.getKey()),
                    type.getValue()
                                 );
        }
        for (Map.Entry<String, BMap<BString, Object>> directive : directives.entrySet()) {
            addValueToRecordField(
                    schemaDirectives,
                    StringUtils.fromString(directive.getKey()),
                    directive.getValue()
                                 );
        }
        addValueToRecordField(graphQLSchemaRecord, ROOT_QUERY_FIELD, types.get(QUERY_TYPE_NAME));
        addValueToRecordField(graphQLSchemaRecord, ROOT_MUTATION_FIELD, types.get(MUTATION_TYPE_NAME));
        addValueToRecordField(graphQLSchemaRecord, ROOT_SUBSCRIPTION_FIELD, types.get(SUBSCRIPTION_TYPE_NAME));

        addValueToRecordField(graphQLSchemaRecord, TYPES_FIELD, schemaRecordTypes);
        addValueToRecordField(graphQLSchemaRecord, DIRECTIVES_FIELD, schemaDirectives);
        return graphQLSchemaRecord;
    }

}
