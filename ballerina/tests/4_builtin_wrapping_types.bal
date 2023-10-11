import ballerina/test;

@test:Config {
    groups: ["builtin", "types", "wrapping"]
}
function testBuiltInWrappingTypes() returns error? {
    string sdl = string `
        type Query {
            strings1: [String]
            strings2: [String!]
            strings3: [String!]!
            strings4: [[[String]]]
        }
    `;
    __Schema expectedSchema = defaultSchema.clone();
    __Field[] fields = [
        { name: "strings1", 'type: { kind: LIST, ofType: String }, args: {} },
        { name: "strings2", 'type: { kind: LIST, ofType: { kind: NON_NULL, ofType: String } }, args: {} },
        { name: "strings3", 'type: { kind: NON_NULL, ofType: { kind: LIST, ofType: { kind: NON_NULL, ofType: String } } }, args: {} },
        { name: "strings4", 'type: { kind: LIST, ofType: { kind: LIST, ofType: { kind: LIST, ofType: String } } }, args: {} }
    ];
    addFieldsToType(expectedSchema, "Query", fields);
    _ = expectedSchema.types.remove("Int");
    _ = expectedSchema.types.remove("Float");
    _ = expectedSchema.types.remove("ID");

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema, expectedSchema);
}