import ballerina/test;

@test:Config {
    groups: ["custom", "types", "scalars"]
}
function testCustomScalarTypes() returns error? {
    string sdl = string `
        scalar Email
        type Query {
            getEmails: [Email!]!
        }
    `;
    __Schema expectedSchema = defaultSchema.clone();
    __Type emailScalarType = {
        kind: SCALAR,
        name: "Email",
        description: ""
    };
    __Field[] queryFields = [
        { name: "getEmails", 'type: { kind: NON_NULL, ofType: { kind: LIST, ofType: { kind: NON_NULL, ofType: emailScalarType } } }, args: {} }
    ];
    expectedSchema.types["Email"] = emailScalarType;
    addFieldsToType(expectedSchema, "Query", queryFields);
    _ = expectedSchema.types.remove("Float");
    _ = expectedSchema.types.remove("Int");
    _ = expectedSchema.types.remove("ID");

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.types["Email"], expectedSchema.types["Email"]);
    test:assertEquals(parsedSchema.types["Query"], expectedSchema.types["Query"]);
    test:assertEquals(parsedSchema, expectedSchema);
}