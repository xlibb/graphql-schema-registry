import ballerina/io;
public function main() {

    string schemaSdl = string `
        extend schema
            @link(url: "https://specs.apollo.dev/federation/v2.3",
                import: ["@key", "@shareable"])        

        type Query {
            t(place: String = "Home"): T
            m: Media
        }
                    
        type T {
            id: [S!]!
        }
                    
        type S @key(fields: "x") {
            x: Int
        }
        
        type R implements Ika & Oka @shareable {
            t: T
            ika: String!
            oka: Int
        }

        input SearchQuery {
            query: String!
            page: Int = 0
        }

        interface Ika implements Oka {
            ika: String!
            oka: Int
        }

        interface Oka {
            oka: Int
        }

        union Media = R | S
    `;

    Parser parser = new(schemaSdl, true);
    __Schema schema = parser.parse();

    io:println(schema.toBalString());

}