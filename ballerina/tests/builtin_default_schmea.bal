__Schema defaultSchema = {
    types: {
        "Float"   : Float,
        "Int"     : Int,
        "ID"      : ID,
        "Query"   : queryType,
        "Boolean" : Boolean,
        "String"  : String
    },
    directives: {
        "deprecated"  : deprecated,
        "skip"        : skip,
        "include"     : include,
        "specifiedBy" : specifiedBy
    },
    queryType: queryType
};

__Type queryType = {
    name: "Query",
    kind: OBJECT,
    fields: {},
    interfaces: []
};

function addFieldsToType(__Schema schema, string 'type, __Field[] 'fields) {
    foreach __Field 'field in 'fields {
        addFieldToType(schema, 'type, 'field);
    }
}

function addFieldToType(__Schema schema, string 'type, __Field 'field) {
    __Type typeRecord = schema.types.get('type);
    map<__Field>? fields = typeRecord.fields;
    if (fields != ()) {
        fields['field.name] = 'field;
    }
}