import ballerina/io;
public function main() {

    string schemaSdl = string `

        directive @join__graph(name: String!, url: String!) on ENUM_VALUE        

        type Query {
            t(place: String = "Home"): T
            m: Media
        }
                    
        type T {
            id: [S!]!
        }
                    
        type S {
            x: Int
        }
        
        type R implements Ika & Oka {
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

    Parser parser = new(schemaSdl);
    __Schema schema = parser.parse();

    io:println(schema.toBalString());

}