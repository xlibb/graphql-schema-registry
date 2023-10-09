import ballerina/io;
public function main() {

    string schemaSdl = string `
        extend schema
            @link(url: "https://specs.apollo.dev/federation/v2.3",
                import: ["@key", "@shareable", "@requiresScopes", "@inaccessible"])        

        scalar CustomScalar @inaccessible

        type Query {
            t(place: String = "Home" @inaccessible, page: Int = 10): T
            m: Media
        }
                    
        type T @key(fields: "id", resolvable: false) {
            id: [S!]!
        }
                    
        type S @key(fields: "x") {
            x: Int @shareable
        }
        
        type R implements Ika & Oka @shareable {
            t: T
            ika: String!
            oka: Int
        }

        input SearchQuery @inaccessible {
            query: String! @inaccessible
            page: Int = 0
            vals: [[Int!]!] = [[10,20], [20], [30]]
        }

        interface Ika implements Oka {
            ika: String!
            oka: Int
        }

        interface Oka @key(fields: "oka") {
            oka: Int
        }

        union Media @inaccessible = R | S

        enum Ombe @inaccessible {
            TYPE @inaccessible 
        }
    `;

    Parser parser = new(schemaSdl, true);
    __Schema schema = parser.parse();

    io:println(schema.toBalString());

}