package io.xlibb.schemaregistry;

import graphql.language.DirectiveDefinition;
import graphql.language.DirectiveLocation;
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
import graphql.schema.GraphQLSchema;
import graphql.schema.GraphQLType;
import graphql.schema.GraphQLUnionType;
import graphql.schema.idl.SchemaGenerator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import io.xlibb.schemaregistry.utils.ParserUtils;
import io.xlibb.schemaregistry.utils.TypeKind;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Parser {
    
    private GraphQLSchema schema;
    private Map<String, BMap<BString, Object>> types;
    private Map<String, BMap<BString, Object>> directives;
    
    public Parser(BString schemaSdl) {
        types = new HashMap<>();
        directives = new HashMap<>();
        schema = SchemaGenerator.createdMockedSchema(schemaSdl.getValue());
    }

    public BMap<BString, Object> parse() {
        addTypesShallow();
        addDirectives();
        addTypesDeep();
        return generateSchemaRecord();
    }

    private void addTypesShallow() {
        for (GraphQLNamedType graphQLType : schema.getTypeMap().values()) {
            BMap<BString, Object> typeRecord = ParserUtils.createRecord(ParserUtils.TYPE_RECORD);
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
                getArgumentsAsBMap(directive.getArguments())
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

            if (graphQLTypeKind.equals(TypeKind.OBJECT)) {
                 populateObjectTypeRecord(typeRecord, (GraphQLObjectType) graphQLType);
            } else if (graphQLTypeKind.equals(TypeKind.ENUM)) {
                populateEnumTypeRecord(typeRecord, (GraphQLEnumType) graphQLType);
            } else if (graphQLTypeKind.equals(TypeKind.UNION)) {
                populateUnionTypeRecord(typeRecord, (GraphQLUnionType) graphQLType);
            } else if (graphQLTypeKind.equals(TypeKind.INPUT_OBJECT)) {
                populateInputTypeRecord(typeRecord, (GraphQLInputObjectType) graphQLType);
            } else if (graphQLTypeKind.equals(TypeKind.INTERFACE)) {
                populateInterfaceTypeRecord(typeRecord, (GraphQLInterfaceType) graphQLType);
            }
        }
    }

    private void populateInterfaceTypeRecord(BMap<BString, Object> typeRecord, GraphQLInterfaceType interfaceType) {
        typeRecord.put(ParserUtils.FIELDS_FIELD, getFieldsAsBMap(interfaceType.getFields()));
        typeRecord.put(ParserUtils.INTERFACES_FIELD, getInterfacesBArray(interfaceType.getInterfaces()));
        // TODO: Interface possible types
    }

    private void populateInputTypeRecord(BMap<BString, Object> typeRecord, GraphQLInputObjectType inputObjectType) {
        typeRecord.put(ParserUtils.INPUT_VALUES_FIELD, getInputFieldsAsBMap(inputObjectType.getFields()));
    }

    private void populateUnionTypeRecord(BMap<BString, Object> typeRecord, GraphQLUnionType unionType) {
        typeRecord.put(ParserUtils.POSSIBLE_TYPES_FIELD, getPossibleTypesAsBArray(unionType.getTypes()));
    }

    private void populateObjectTypeRecord(BMap<BString, Object> typeRecord, GraphQLObjectType objectType) {
        typeRecord.put(ParserUtils.FIELDS_FIELD, getFieldsAsBMap(objectType.getFields()));
        typeRecord.put(ParserUtils.INTERFACES_FIELD, getInterfacesBArray(objectType.getInterfaces()));
    }

    private void populateEnumTypeRecord(BMap<BString, Object> typeRecord, GraphQLEnumType enumType) {
        typeRecord.put(ParserUtils.ENUM_FIELD, getEnumValuesAsBArray(enumType.getValues()));
    }

    private BArray getInterfacesBArray(List<GraphQLNamedOutputType> interfaces) {
        BArray interfacesBArray = ParserUtils.createBArrayFromRecord(
                                    ParserUtils.createRecord(ParserUtils.TYPE_RECORD));
        for (GraphQLNamedOutputType graphQLType : interfaces) {
            interfacesBArray.append(getTypeAsRecord(graphQLType));
        }
        return interfacesBArray;
    }

    private BMap<BString, Object> getInputFieldsAsBMap(List<GraphQLInputObjectField> fields) {
        GraphQLInputValueDefinition[] inputValueDefinitions = new GraphQLInputValueDefinition[fields.size()];
        fields.toArray(inputValueDefinitions);
        return getInputValuesAsBMap(inputValueDefinitions);
    }

    private BMap<BString, Object> getArgumentsAsBMap(List<GraphQLArgument> arguments) {
        GraphQLInputValueDefinition[] inputValueDefinitions = new GraphQLInputValueDefinition[arguments.size()];
        arguments.toArray(inputValueDefinitions);
        return getInputValuesAsBMap(inputValueDefinitions);
    }

    private BMap<BString, Object> getInputValuesAsBMap(GraphQLInputValueDefinition[] fields) {
        BMap<BString, Object> inputValueRecordsMap = ValueCreator.createMapValue();
        for (GraphQLInputValueDefinition inputValueDefinition : fields) {
            BMap<BString, Object> inputValueRecord = ParserUtils.createRecord(ParserUtils.INPUT_VALUE_RECORD);
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
                getInputDefaultAsBString(inputValueDefinition)
            );

            inputValueRecordsMap.put(
                StringUtils.fromString(inputValueDefinition.getName()),
                inputValueRecord
            );
        }
        return inputValueRecordsMap;
    }

    private BString getInputDefaultAsBString(GraphQLInputValueDefinition input) {
        Object defaultValue = null;
        if (input.getClass().equals(GraphQLArgument.class) 
                && ((GraphQLArgument) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLArgument) input).getArgumentDefaultValue().getValue();

        } else if (input.getClass().equals(GraphQLInputObjectField.class)
                && ((GraphQLInputObjectField) input).hasSetDefaultValue()) {
            defaultValue = ((GraphQLInputObjectField) input).getInputFieldDefaultValue().getValue();
        }
        return (defaultValue != null) ?  StringUtils.fromString(defaultValue.toString()) : null;
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
            fieldRecord.put(ParserUtils.ARGS_FIELD, getArgumentsAsBMap(fieldDefinition.getArguments()));
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
            schemaRecordTypes.put(StringUtils.fromString(type.getKey()), type.getValue());
        }
        for (Map.Entry<String, BMap<BString, Object>> directive : directives.entrySet()) {
            schemaDirectives.put(StringUtils.fromString(directive.getKey()), directive.getValue());
        }
        graphQLSchemaRecord.put(ParserUtils.TYPES_FIELD, schemaRecordTypes);
        graphQLSchemaRecord.put(ParserUtils.DIRECTIVES_FIELD, schemaDirectives);
        return graphQLSchemaRecord;
    }

}
