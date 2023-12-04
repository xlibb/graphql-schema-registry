package io.xlibb.schemaregistry;

import graphql.GraphQLError;
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
import graphql.schema.GraphQLInputType;
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
import graphql.schema.idl.errors.SchemaProblem;
import io.ballerina.runtime.api.PredefinedTypes;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BIterator;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.internal.types.BAnyType;
import io.xlibb.schemaregistry.utils.FederationUtils;
import io.xlibb.schemaregistry.utils.ModuleUtils;
import io.xlibb.schemaregistry.utils.ParserUtils.ParsingMode;
import io.xlibb.schemaregistry.utils.ParserWiringFactory;
import io.xlibb.schemaregistry.utils.TypeKind;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

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
import static io.xlibb.schemaregistry.utils.ParserUtils.createRecordMap;
import static io.xlibb.schemaregistry.utils.ParserUtils.createBArrayFromRecord;
import static io.xlibb.schemaregistry.utils.ParserUtils.getTypeKindFromType;

public class Parser {

    private GraphQLSchema schema;
    private Map<String, GraphQLNamedType> filteredTypeMap;
    private Map<String, BMap<BString, Object>> types;
    private Map<String, BMap<BString, Object>> directives;
    private final String schemaSdl;
    private final String parsingMode;

    public Parser(BString schemaSdl, BString modeStr) {

        types = new HashMap<>();
        directives = new HashMap<>();
        this.schemaSdl = schemaSdl.getValue(); 
        this.parsingMode = modeStr.getValue();
    }

    public Object parse() {

        BArray errors = init();
        if (errors.getLength() > 0) {
            return errors;
        }
        addTypesShallow();
        addEnumsDeepWithoutAppliedDirectives();
        addDirectivesShallow();
        addDirectivesDeep();
        addEnumsDeepWithAppliedDirectives();
        addTypesDeep();
        return generateSchemaRecord();
    }

    private BArray init() {
        SchemaParser parser = new SchemaParser();
        ArrayType recordType = TypeCreator.createArrayType(PredefinedTypes.TYPE_ERROR);
        BArray bArray = ValueCreator.createArrayValue(recordType);
        try {
            TypeDefinitionRegistry schemaDefinitions = parser.parse(this.schemaSdl);
            switch (ParsingMode.valueOf(this.parsingMode)) {
                case SUBGRAPH_SCHEMA -> {
                    TypeDefinitionRegistry federationDefinitions = FederationUtils
                                                                                .getFederationTypes(schemaDefinitions);
                    schemaDefinitions = schemaDefinitions.merge(federationDefinitions);
                }
                case SUPERGRAPH_SCHEMA -> {
                }
                case SCHEMA -> {
                }
            }

            RuntimeWiring wiring = RuntimeWiring.newRuntimeWiring().wiringFactory(new ParserWiringFactory()).build();
            this.schema = (new SchemaGenerator()).makeExecutableSchema(schemaDefinitions, wiring);
            this.filteredTypeMap = schema.getTypeMap().entrySet().stream()
                                                    .filter(e -> !isIntrospectionType(e.getValue()))
                                                    .collect(Collectors.toMap(e->e.getKey(), e->e.getValue()));
        } catch (SchemaProblem problem) {
            for (GraphQLError error : problem.getErrors()) {
                BError bError = ErrorCreator.createError(StringUtils.fromString(error.getMessage()));
                bArray.append(bError);
            }
        }
        return bArray;
    }

    private void addTypesShallow() {

        for (GraphQLNamedType graphQLType : filteredTypeMap.values()) {
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

    private void addDirectivesShallow() {

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
                    DIRECTIVE_LOCATIONS_FIELD,
                    getDirectiveLocationsAsBArray(directive.validLocations().stream().map(l -> l.name()).toList())
                                    );

            DirectiveDefinition directiveDefinition = directive.getDefinition();
            if (directiveDefinition != null) {
                addValueToRecordField(
                        directiveRecord,
                        DIRECTIVE_IS_REPEATABLE_FIELD,
                        directiveDefinition.isRepeatable()
                                     );
                addValueToRecordField(
                        directiveRecord,
                        DIRECTIVE_LOCATIONS_FIELD,
                        getDirectiveLocationsAsBArray(directiveDefinition.getDirectiveLocations()
                                                                         .stream().map(l -> l.getName()).toList())
                                        );
            }
            directives.put(directive.getName(), directiveRecord);
        }
    }

    private void addDirectivesDeep() {

        for (GraphQLDirective directive : schema.getDirectives()) {
            BMap<BString, Object> directiveRecord = directives.get(directive.getName());
            addValueToRecordField(
                    directiveRecord,
                    ARGS_FIELD,
                    getInputValuesAsBMap(directive.getArguments())
                                );
        }
    }

    private void addTypesDeep() {

        for (GraphQLNamedType graphQLType : filteredTypeMap.values()) {

            BMap<BString, Object> typeRecord = types.get(graphQLType.getName());
            TypeKind graphQLTypeKind = getTypeKindFromType(graphQLType);

            switch (graphQLTypeKind) {
                case OBJECT -> populateObjectTypeRecord(typeRecord, (GraphQLObjectType) graphQLType);
                case UNION -> populateUnionTypeRecord(typeRecord, (GraphQLUnionType) graphQLType);
                case INPUT_OBJECT -> populateInputTypeRecord(typeRecord, (GraphQLInputObjectType) graphQLType);
                case INTERFACE -> populateInterfaceTypeRecord(typeRecord, (GraphQLInterfaceType) graphQLType);
                case SCALAR -> populateScalarTypeRecord(typeRecord, (GraphQLScalarType) graphQLType);
                default -> {
                }
            }
        }
    }

    private void addEnumsDeepWithoutAppliedDirectives() {
        for (GraphQLNamedType type : filteredTypeMap.values()) {
            if (type instanceof GraphQLEnumType) {
                GraphQLEnumType enumType = (GraphQLEnumType) type;
                BMap<BString, Object> enumTypeRecord = types.get(enumType.getName());
                addValueToRecordField(
                        enumTypeRecord, 
                        ENUM_FIELD, 
                        getEnumValuesWithoutAppliedDirectivesAsBArray(enumType.getValues())
                );
            }
        }
    }

    private void addEnumsDeepWithAppliedDirectives() {
        for (GraphQLNamedType enumType : filteredTypeMap.values()) {
            if (enumType instanceof GraphQLEnumType) {
                BMap<BString, Object> enumTypeRecord = types.get(enumType.getName());
                addValueToRecordField(
                        enumTypeRecord,
                        APPLIED_DIRECTIVES_FIELD,
                        getAppliedDirectivesAsBArray(((GraphQLEnumType) enumType).getAppliedDirectives())
                                    );
                populateEnumValuesAppliedDirectives(enumTypeRecord, ((GraphQLEnumType) enumType));
            }
        }
    }

    private void populateEnumValuesAppliedDirectives(BMap<BString, Object> enumTypeRecord, GraphQLEnumType enumType) {
        BArray enumValues = (BArray) enumTypeRecord.get(ENUM_FIELD);

        @SuppressWarnings("unchecked")
        BIterator<BMap<BString, Object>> iterator = (BIterator<BMap<BString, Object>>) enumValues.getIterator();
        while (iterator.hasNext()) {
            BMap<BString, Object> enumValueRecord = iterator.next();
            String enumValueName = enumValueRecord.get(NAME_FIELD).toString();
            GraphQLEnumValueDefinition enumValueDefinition = enumType.getValue(enumValueName);
            addValueToRecordField(
                    enumValueRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBArray(enumValueDefinition.getAppliedDirectives())
                                );
        }
    }

    private void populateScalarTypeRecord(BMap<BString, Object> typeRecord, GraphQLScalarType scalarType) {

        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBArray(scalarType.getAppliedDirectives())
                             );
    }

    private void populateInterfaceTypeRecord(BMap<BString, Object> typeRecord, GraphQLInterfaceType interfaceType) {

        addValueToRecordField(typeRecord, FIELDS_FIELD, getFieldsAsBMap(interfaceType.getFields()));
        addValueToRecordField(typeRecord, INTERFACES_FIELD, getInterfacesBArray(interfaceType.getInterfaces()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBArray(interfaceType.getAppliedDirectives())
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
                getAppliedDirectivesAsBArray(inputObjectType.getAppliedDirectives())
                             );
    }

    private void populateUnionTypeRecord(BMap<BString, Object> typeRecord, GraphQLUnionType unionType) {

        addValueToRecordField(typeRecord, POSSIBLE_TYPES_FIELD, getPossibleTypesAsBArray(unionType.getTypes()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBArray(unionType.getAppliedDirectives())
                             );
    }

    private void populateObjectTypeRecord(BMap<BString, Object> typeRecord, GraphQLObjectType objectType) {

        addValueToRecordField(typeRecord, FIELDS_FIELD, getFieldsAsBMap(objectType.getFields()));
        addValueToRecordField(typeRecord, INTERFACES_FIELD, getInterfacesBArray(objectType.getInterfaces()));
        addValueToRecordField(
                typeRecord,
                APPLIED_DIRECTIVES_FIELD,
                getAppliedDirectivesAsBArray(objectType.getAppliedDirectives())
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

        BMap<BString, Object> inputValueRecordsMap = createRecordMap(INPUT_VALUE_RECORD);
        for (GraphQLInputValueDefinition inputValueDefinition : fields) {
            BMap<BString, Object> inputValueRecord = createRecord(INPUT_VALUE_RECORD);
            addValueToRecordField(
                    inputValueRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBArray(inputValueDefinition.getAppliedDirectives())
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

            inputValueRecordsMap.put(
                    StringUtils.fromString(inputValueDefinition.getName()),
                    inputValueRecord);
        }
        return inputValueRecordsMap;
    }

    private Object getInputDefaultAsBType(GraphQLInputValueDefinition input) {

        Object defaultValue = null;
        if (input instanceof GraphQLArgument && ((GraphQLArgument) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLArgument) input).getArgumentDefaultValue().getValue();
        } else if (input instanceof GraphQLInputObjectField && ((GraphQLInputObjectField) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLInputObjectField) input).getInputFieldDefaultValue().getValue();
        }
        GraphQLInputType typeDefinition = ((GraphQLInputValueDefinition) input).getType();
        return defaultValue == null ? null : getValueAsBType(defaultValue, typeDefinition);
    }

    private Object getValueAsBType(Object valueObject, GraphQLInputType typeDefinition) {

        if (valueObject instanceof FloatValue) {
            return ((FloatValue) valueObject).getValue().doubleValue();
        } else if (valueObject instanceof IntValue) {
            return ((IntValue) valueObject).getValue().intValue();
        } else if (valueObject instanceof StringValue) {
            return StringUtils.fromString(((StringValue) valueObject).getValue());
        } else if (valueObject instanceof BooleanValue) {
            return ((BooleanValue) valueObject).isValue();
        } else if (valueObject instanceof EnumValue) {
            return getEnumValueDefinitionFromInputValue(typeDefinition, (EnumValue) valueObject);
        } else if (valueObject instanceof ArrayValue) {
            ArrayType arrayType = TypeCreator.createArrayType(new BAnyType(ANYDATA, ModuleUtils.getModule(), false));
            BArray bArray = ValueCreator.createArrayValue(arrayType);
            for (Value<?> value : ((ArrayValue) valueObject).getValues()) {
                bArray.append(getValueAsBType(value, typeDefinition));
            }
            return bArray;
        } else {
            return null;
        }
    }

    private Object getAppliedDirectivesAsBArray(List<GraphQLAppliedDirective> appliedDirectives) {

        BArray appliedDirectivesBArray = createBArrayFromRecord(createRecord(APPLIED_DIRECTIVE_RECORD));
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

            appliedDirectivesBArray.append(appliedDirectiveRecord);;
        }
        return appliedDirectivesBArray;
    }

    private Object getAppliedDirectiveArgumentsAsBMap(List<GraphQLAppliedDirectiveArgument> arguments) {

        BMap<BString, Object> argumentsBMap = createRecordMap(APPLIED_DIRECTIVE_INPUT_VALUE_RECORD);
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
                    getValueAsBType(argument.getArgumentValue().getValue(), argument.getType())
                                 );

            argumentsBMap.put(
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

    private BArray getEnumValuesWithoutAppliedDirectivesAsBArray(List<GraphQLEnumValueDefinition> enumValueDefs) {

        BArray enumValuesBArray = createBArrayFromRecord(createRecord(ENUM_VALUE_RECORD));
        for (GraphQLEnumValueDefinition enumValueDefinition : enumValueDefs) {
            BMap<BString, Object> enumValueRecord = createRecord(ENUM_VALUE_RECORD);
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

    private Object getEnumValueDefinitionFromInputValue(GraphQLInputType typeDefinition, EnumValue valueObject) {

        BString enumValueName = StringUtils.fromString(valueObject.getName());
        BMap<BString, Object> enumTypeRecord = getTypeAsRecord(getUnWrappedType(typeDefinition));
        BArray enumValues = (BArray) enumTypeRecord.get(ENUM_FIELD);
        Object enumValueDefinition = null;

        @SuppressWarnings("unchecked")
        BIterator<BMap<BString, Object>> iterator = (BIterator<BMap<BString, Object>>) enumValues.getIterator();
        while (iterator.hasNext()) {
            BMap<BString, Object> enumValue = iterator.next();
            if (enumValue.get(NAME_FIELD).equals(enumValueName)) {
                enumValueDefinition = enumValue;
                break;
            }
        }
        return enumValueDefinition;
    }

    private BArray getDirectiveLocationsAsBArray(List<String> list) {
        List<BString> locationsArray = list.stream().map(l -> StringUtils.fromString(l)).toList();
        BString[] locationsBArray = new BString[list.size()];
        locationsArray.toArray(locationsBArray);
        return ValueCreator.createArrayValue(locationsBArray);
    }

    private BMap<BString, Object> getFieldsAsBMap(List<GraphQLFieldDefinition> fields) {

        BMap<BString, Object> fieldsBMap = createRecordMap(FIELD_RECORD);
        for (GraphQLFieldDefinition fieldDefinition : fields) {
            BMap<BString, Object> fieldRecord = createRecord(FIELD_RECORD);
            addValueToRecordField(fieldRecord, NAME_FIELD, StringUtils.fromString(fieldDefinition.getName()));
            addValueToRecordField(fieldRecord, TYPE_FIELD, getTypeAsRecord(fieldDefinition.getType()));
            addValueToRecordField(fieldRecord, ARGS_FIELD, getInputValuesAsBMap(fieldDefinition.getArguments()));
            addValueToRecordField(
                    fieldRecord,
                    APPLIED_DIRECTIVES_FIELD,
                    getAppliedDirectivesAsBArray(fieldDefinition.getAppliedDirectives())
                                 );
            addValueToRecordField(
                    fieldRecord,
                    DESCRIPTION_FIELD,
                    StringUtils.fromString(fieldDefinition.getDescription())
                                );
            addValueToRecordField(
                    fieldRecord,
                    IS_DEPRECATED_FIELD,
                    fieldDefinition.isDeprecated()
                                 );
            addValueToRecordField(
                    fieldRecord,
                    DEPRECATION_REASON_FIELD,
                    StringUtils.fromString(fieldDefinition.getDeprecationReason())
                                 );
            fieldsBMap.put(StringUtils.fromString(fieldDefinition.getName()), fieldRecord);
        }
        return fieldsBMap;
    }

    private BMap<BString, Object> getTypeAsRecord(GraphQLType type) {

        BMap<BString, Object> typeRecord;
        if (type instanceof GraphQLList || type instanceof GraphQLNonNull) {
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

    private GraphQLType getUnWrappedType(GraphQLType type) {
        if (type instanceof GraphQLList || type instanceof GraphQLNonNull) {
            return getUnWrappedType(((GraphQLModifiedType) type).getWrappedType());
        } else {
            return type;
        }
    }

    private boolean isIntrospectionType(GraphQLNamedType graphQLType) {

        return (graphQLType.getName().startsWith("__"));
    }

    private BMap<BString, Object> generateSchemaRecord() {

        BMap<BString, Object> graphQLSchemaRecord = createRecord(SCHEMA_RECORD);
        BMap<BString, Object> schemaRecordTypes = createRecordMap(TYPE_RECORD);
        BMap<BString, Object> schemaDirectives = createRecordMap(DIRECTIVE_RECORD);
        for (Map.Entry<String, BMap<BString, Object>> type : types.entrySet()) {
            schemaRecordTypes.put(
                    StringUtils.fromString(type.getKey()),
                    type.getValue());
        }
        for (Map.Entry<String, BMap<BString, Object>> directive : directives.entrySet()) {
            schemaDirectives.put(
                    StringUtils.fromString(directive.getKey()),
                    directive.getValue());
        }
        addValueToRecordField(graphQLSchemaRecord, ROOT_QUERY_FIELD, types.get(QUERY_TYPE_NAME));
        addValueToRecordField(graphQLSchemaRecord, ROOT_MUTATION_FIELD, types.get(MUTATION_TYPE_NAME));
        addValueToRecordField(graphQLSchemaRecord, ROOT_SUBSCRIPTION_FIELD, types.get(SUBSCRIPTION_TYPE_NAME));

        addValueToRecordField(graphQLSchemaRecord, TYPES_FIELD, schemaRecordTypes);
        addValueToRecordField(graphQLSchemaRecord, DIRECTIVES_FIELD, schemaDirectives);

        addValueToRecordField(graphQLSchemaRecord, APPLIED_DIRECTIVES_FIELD, 
                                                    getAppliedDirectivesAsBArray(schema.getSchemaAppliedDirectives())
                              );
        return graphQLSchemaRecord;
    }

}
