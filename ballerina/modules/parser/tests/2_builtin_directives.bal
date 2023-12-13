import ballerina/test;

@test:Config {
    groups: ["builtin", "directives"],
    dataProvider:  dataProviderBuiltInDirectives
}
function testBuiltInDirectives(__Directive expectedDirective) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
}

function dataProviderBuiltInDirectives() returns [__Directive][] {
    return [ 
        [builtInDirectives.get(DEPRECATED_DIR)],
        [builtInDirectives.get(SKIP_DIR)],
        [builtInDirectives.get(INCLUDE_DIR)],
        [builtInDirectives.get(SPECIFIED_BY_DIR)]
    ];
}