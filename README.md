# GraphQL Schema Registry

Graphql Schema Registry self-hostable service for Federated GraphQL Services as an alternative to [Apollo studio](https://studio.apollographql.com/).

## Features
-  **Perform Dry Runs**: Verify a given Subgraph for Supergraph composition before publishing it.
-   **Publish Subgraph**: Publish a Subgraph to the Schema Registry for Supergraph composition.
-   **Prevent Breaking Changes**: Ensure Subgraphs don't cause breaking changes to the Supergraph.
-   **Automatic Versioning**: Automatically versions the Supergraph based on the changes that occurred to it in the format of `[Breaking].[Dangerous].[Safe]`. (Similar to Semantic Versioning)
-   **Get Supergraph Schema/API Schema**: Access Supergraph and its API Schema.
-   **Get Supergraph Differences**: Compare two Supergraphs and generate a diff between the two.
- **Categorize Diff Type** - Automatically categorize the changes occured to a Schema into **Breaking**, **Dangerous** and **Safe**.
- **Data-Agnostic**: Allows any datasource integration. (MongoDB, File-based storage and In-memory storage are supported by default)
-   **Get Registered Subgraph by Name**: Retrieve Subgraph from Registry.
## Installation
### Prerequisites
[Download](https://adoptopenjdk.net/) and install Java SE Development Kit (JDK) version 17.

### Building
1. Clone this repository using the following command.
```
git clone https://github.com/xlibb/graphql-schema-registry
```
2. Run the gradle build command `./gradlew build` from the repository root directory. This will generate the jar file `graphql_schema_registry.jar` in `ballerina/target/bin` directory.

### Configuration
1. Create a `Config.toml` in the same directory as the built `graphql_schema_registry.jar` file. An example `Config.toml.example` can be found on the `ballerina` directory.
2. Use the following content for the MongoDB configuration
```
[mongoConfig]
connection.url = "mongodb+srv://<username>:<password>@<mongo_cluster>.mongodb.net"
databaseName = "graphql-schema-registry"
```
### Starting the Schema Registry
Run the jar file using `java -jar graphql_schema_registry.jar`.

## Architecture

![Architecture for the GraphQL Schema Registry](https://private-user-images.githubusercontent.com/66688464/273110038-8fe6e879-4cce-4152-8922-350b1300fb58.jpg?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MDYzMTkxNTIsIm5iZiI6MTcwNjMxODg1MiwicGF0aCI6Ii82NjY4ODQ2NC8yNzMxMTAwMzgtOGZlNmU4NzktNGNjZS00MTUyLTg5MjItMzUwYjEzMDBmYjU4LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDAxMjclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQwMTI3VDAxMjczMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTY1NDdlOTk5NDc4ZWFiNTExNDljMzEwODM4OTBiNmE2MzYwMWQ5MzkzZmNhOTY4ZDZkZWMxYmQ3NjZhODA3NTgmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JmFjdG9yX2lkPTAma2V5X2lkPTAmcmVwb19pZD0wIn0.cvXDdbfMumaVs_VK-GRzToSlFie_FPEEIdbrE7iHhwc)
### Components
| Name | Role |
|--|--|
| Parser | Parses GraphQL SDL and create a `parser:__Schema` record |
| Merger | Merges a given array of Subgraphs (of type `merger:Subgraph` type) and generate a Supergraph (of type `merger:Supergraph`)
| Differ | Generates a diff between two given `parser:__Schema` types |
| Exporter | Exports a `parser:__Schema` into a GraphQL SDL String |
| Datasource | This module serves as the persistence layer of the Schema Registry. It defines an interface that any datasource must implement to integrate with the Schema Registry. |
| Registry | Acts as the Controller between all of the above components/modules |
| GraphQL API | GraphQL API provides users access to the Schema Registry |

### GraphQL API
GraphQL Schema for the Schema Registry
```graphql
type Query {
  supergraph: Supergraph!
  supergraphVersions: [String!]!
  dryRun(schema: SubgraphInput!, isForced: Boolean! = false): CompositionResult
  subgraph(name: String!): Subgraph!
  diff(newVersion: String!, oldVersion: String!): [SchemaDiff!]!
}

type Supergraph {
  subgraphs: [Subgraph!]!
  schema: String!
  version: String!
  apiSchema: String!
}

type Subgraph {
  name: String!
  schema: String!
}

type CompositionResult {
  subgraphs: [Subgraph!]!
  schema: String!
  version: String!
  apiSchema: String!
  hints: [String!]!
  diffs: [SchemaDiff!]!
}

type SchemaDiff {
  severity: DiffSeverity!
  action: DiffAction!
  subject: DiffSubject!
  location: [String!]!
  value: String
  fromValue: String
  toValue: String
}

enum DiffSeverity {
  SAFE
  DANGEROUS
  BREAKING
}

enum DiffAction {
  CHANGED
  REMOVED
  ADDED
}

enum DiffSubject {
  UNION_MEMBER
  INTERFACE_IMPLEMENTATION
  ENUM_DEPRECATION
  ENUM_DESCRIPTION
  ENUM
  INPUT_FIELD_DESCRIPTION
  INPUT_FIELD_TYPE
  INPUT_FIELD_DEFAULT
  INPUT_FIELD
  ARGUMENT_DESCRIPTION
  ARGUMENT_DEFAULT
  ARGUMENT_TYPE
  ARGUMENT
  FIELD_DESCRIPTION
  FIELD_TYPE
  FIELD_DEPRECATION
  FIELD
  TYPE_DESCRIPTION
  TYPE_KIND
  TYPE
  DIRECTIVE_DESCRIPTION
  DIRECTIVE
}

input SubgraphInput {
  name: String!
  url: String!
  schema: String!
}

type Mutation {
  publishSubgraph(schema: SubgraphInput!, isForced: Boolean! = false): CompositionResult
}
```

More details for this project can be found [here.](https://github.com/ballerina-platform/ballerina-library/issues/4820)