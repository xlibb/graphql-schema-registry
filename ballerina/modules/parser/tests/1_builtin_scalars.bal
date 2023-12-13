import ballerina/test;

@test:Config {
    groups: ["builtin", "scalars"],
    dataProvider:  dataProviderBuiltInScalars
}
function testBuiltInScalars(string scalarName, __Type expectedScalar) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.types.get(scalarName), expectedScalar);
}

function dataProviderBuiltInScalars() returns [string, __Type][] {
    return [
        [BOOLEAN, builtInTypes.get(BOOLEAN) ],
        [STRING , builtInTypes.get(STRING)  ],
        [FLOAT  , builtInTypes.get(FLOAT)   ],
        [INT    , builtInTypes.get(INT)     ],
        [ID     , builtInTypes.get(ID)      ]
   ];
}