import ballerina/test;

@test:Config {
    groups: ["builtin", "scalars"],
    dataProvider:  dataProviderBuiltInScalars
}
function testBuiltInScalars(string scalarName, __Type expectedScalar) returns error? {
    string sdl = string `
        type Query {
            string: String
            bool: Boolean
            float: Float
            id: ID
            int: Int
        }
    `;
    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types.get(scalarName), expectedScalar);
}

function dataProviderBuiltInScalars() returns map<[string, __Type]> {
    return { 
        "Boolean": ["Boolean", Boolean],
        "String" : ["String", String],
        "Float"  : ["Float", Float],
        "Int"    : ["Int", Int],
        "ID"     : ["ID", ID]
    };
}