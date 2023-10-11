import ballerina/test;

@test:Config {
    groups: ["custom", "types", "object"]
}
function testCustomObjectTypes() returns error? {
    string sdl = string `
        type Query {
            person: Person!
            address: Address
        }

        type Person {
            id: ID!
            name: String!
            age: Int!
            isMarried: Boolean!
            average: Float
            address: Address!
        }

        type Address {
            no: Int!
            street: String
            village: String!
            town: String!
        }
    `;
    __Schema expectedSchema = defaultSchema.clone();
    __Type addressType = {
        kind: OBJECT,
        name: "Address",
        fields: {
            "no": { name: "no", args: {}, 'type: { kind: NON_NULL, ofType: Int } },
            "street": { name: "street", args: {}, 'type: String },
            "village": { name: "village", args: {}, 'type: { kind: NON_NULL, ofType: String } },
            "town": { name: "town", args: {}, 'type: { kind: NON_NULL, ofType: String } }
        },
        interfaces: []
    };
    __Type personType = {
        kind: OBJECT,
        name: "Person",
        fields: {
            "id": { name: "id", args: {}, 'type: { kind: NON_NULL, ofType: ID } },
            "name": { name: "name", args: {}, 'type: { kind: NON_NULL, ofType: String } },
            "age": { name: "age", args: {}, 'type: { kind: NON_NULL, ofType: Int } },
            "isMarried": { name: "isMarried", args: {}, 'type: { kind: NON_NULL, ofType: Boolean } },
            "average": { name: "average", args: {}, 'type: Float },
            "address": { name: "address", args: {}, 'type: { kind: NON_NULL, ofType: addressType } }
        },
        interfaces: []
    };

    __Field[] queryFields = [
        { name: "person", 'type: { kind: NON_NULL, ofType: personType }, args: {} },
        { name: "address", 'type: addressType, args: {} }
    ];
    addFieldsToType(expectedSchema, "Query", queryFields);
    expectedSchema.types["Person"] = personType;
    expectedSchema.types["Address"] = addressType;

    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema, expectedSchema);
}