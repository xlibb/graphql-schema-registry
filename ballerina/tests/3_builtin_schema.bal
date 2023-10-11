import ballerina/test;

@test:Config {
    groups: ["builtin", "schema"]
}
function testBuiltInSchema() returns error? {
    string sdl = string `
        type Query {
            string: String
            float: Float
            boolean: Boolean
            id: ID
            int: Int
        }
    `;
    __Schema expectedSchema = defaultSchema.clone();
    __Field[] fields = [
        { name: "string", 'type: String, args: {} },
        { name: "float", 'type: Float, args: {} },
        { name: "boolean", 'type: Boolean, args: {} },
        { name: "id", 'type: ID, args: {} },
        { name: "int", 'type: Int, args: {} }
    ];
    addFieldsToType(expectedSchema, "Query", fields);

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types, expectedSchema.types);
}