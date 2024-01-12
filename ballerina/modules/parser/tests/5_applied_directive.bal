// Copyright (c) 2024 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;

@test:Config {
    groups: ["builtin", "applied_directives"],
    dataProvider: dataProviderAppliedDirective
}
function testAppliedDirective(string fileName, string fieldName, __AppliedDirective[] expectedAppliedDirectives) returns error? { 
    string sdl = check getGraphqlSdlFromFile(fileName);

    __Schema parsedSchema = check parseSdl(sdl);
    map<__Field>? fields = parsedSchema.queryType.fields;
    if (fields != ()) {
        __AppliedDirective[] appliedDirectives = fields.get(fieldName).appliedDirectives;
        test:assertEquals(appliedDirectives, expectedAppliedDirectives);
    } else {
        test:assertFail("No fields on Query");
    }
 }

 function dataProviderAppliedDirective() returns map<[string, string, __AppliedDirective[]]> {
    return {
        "1": ["applied_directive", "name", 
                [ 
                    {
                        args: {
                            [REASON_FIELD]: {
                                value: "This field is deprecated",
                                definition: builtInTypes.get(STRING)
                            }
                        },
                        definition: builtInDirectives.get(DEPRECATED_DIR)
                    }
                ]
        ],
        "2": ["applied_directive_default_value", "name", 
                [ 
                    {
                        args: {
                            [REASON_FIELD]: {
                                value: REASON_FIELD_DEFAULT_VALUE,
                                definition: builtInTypes.get(STRING)
                            }
                        },
                        definition: builtInDirectives.get(DEPRECATED_DIR)
                    }
                ]
        ]                                                    
    };
 }

@test:Config {
    groups: ["builtin", "applied_directives", "input_values"],
    dataProvider: dataProviderAppliedDirectiveInputValue
}
function testAppliedDirectiveInputValue(string argName, __AppliedDirectiveInputValue expected_value) returns error? {
    string sdl = check getGraphqlSdlFromFile("applied_directive_input_value");

    __Schema parsedSchema = check parseSdl(sdl);
    __AppliedDirective[] appliedDirectives = parsedSchema.types.get("Student").appliedDirectives;
    __AppliedDirective testDirective = appliedDirectives.filter(d => d.definition.name == "testDirective")[0];
    map<__AppliedDirectiveInputValue> input_values = testDirective.args;

    test:assertEquals(input_values[argName], expected_value);
}

function dataProviderAppliedDirectiveInputValue() returns [string, __AppliedDirectiveInputValue][] {
    __EnumValue enum_VAL1 = { name: "VAL1" };
    __EnumValue enum_VAL2 = { name: "VAL2" };

    __Type enum_type = {
        name: "TestEnum",
        kind: ENUM,
        enumValues: [ enum_VAL1, enum_VAL2 ]
    };

    return [
        ["name",    { definition: wrapType(builtInTypes.get(STRING), NON_NULL),                 value: "Hello" }],
        ["age",     { definition: wrapType(builtInTypes.get(INT), NON_NULL),                    value: 10 }],
        ["avg",     { definition: wrapType(builtInTypes.get(FLOAT), NON_NULL),                  value: 24.5 }],
        ["is",      { definition: wrapType(builtInTypes.get(BOOLEAN), NON_NULL),                value: false }],
        ["list",    { definition: wrapType(wrapType(builtInTypes.get(STRING), LIST), NON_NULL), value: ["A", "B"] }],
        ["enum",    { definition: wrapType(enum_type, NON_NULL),                                value: enum_VAL1 }]
    ];
}

@test:Config {
    groups: ["builtin", "applied_directives", "input_values"]
}
function testAppliedDirectiveEnumValueCyclic() returns error? {
    string sdl = check getGraphqlSdlFromFile("applied_directive_input_value_cyclic_enum");

    __Type firstEnum = {
        name: "FirstEnum",
        kind: ENUM,
        enumValues: [
            { name: "YES" },
            { name: "NO" }
        ]
    };
    __Type secondEnum = {
        name: "SecondEnum",
        kind: ENUM,
        enumValues: [
            { name: "True" },
            { name: "False" }
        ]
    };

    __Directive firstEnumDirective = { 
        name: "FirstEnumDirective", 
        locations: [ ENUM_VALUE ], 
        args: {
            "enum": { name: "enum", 'type: firstEnum }
        },
        isRepeatable: false
    };
    __Directive secondEnumDirective = { 
        name: "SecondEnumDirective", 
        locations: [ ENUM_VALUE ], 
        args: {
            "enum": { name: "enum", 'type: secondEnum }
        },
        isRepeatable: false
    };

    __EnumValue firstEnumYesValue = (<__EnumValue[]> firstEnum.enumValues)[0];
    __EnumValue secondEnumTrueValue = (<__EnumValue[]> secondEnum.enumValues)[0];
    firstEnumYesValue.appliedDirectives.push(
        { 
            args: { 
                "enum": {
                    value: secondEnumTrueValue,
                    definition: secondEnum
                }
            }, 
            definition: secondEnumDirective
        }
    );
    secondEnumTrueValue.appliedDirectives.push(
        { 
            args: { 
                "enum": {
                    value: firstEnumYesValue,
                    definition: firstEnum
                }
            }, 
            definition: firstEnumDirective
        }
    );

    __Schema parsedSchema = check parseSdl(sdl);
    __EnumValue[]? firstEnumValues = parsedSchema.types.get("FirstEnum").enumValues;
    __EnumValue[]? secondEnumValues = parsedSchema.types.get("SecondEnum").enumValues;
    if firstEnumValues !is () && secondEnumValues !is () {
        test:assertEquals(firstEnumValues, firstEnum.enumValues);
        test:assertEquals(secondEnumValues, secondEnum.enumValues);
    }
}

@test:Config {
    groups: ["builtin", "applied_directives", "input_values"]
}
function testAppliedDirectiveOnDirectiveDefinition() returns error? { 
    string sdl = check getGraphqlSdlFromFile("applied_directive_on_directive_definition");

    __Directive foo = {
        name: "foo",
        args: {}, 
        isRepeatable: false,
        locations: [ INPUT_FIELD_DEFINITION ]
    };
    __AppliedDirective applied_foo = {
        args: {},
        definition: foo
    };
    __Directive bar = {
        name: "bar",
        args: {
            "name": { 
                name: "name", 
                appliedDirectives: [applied_foo],
                'type: builtInTypes.get(STRING)
            }
        }, 
        isRepeatable: false,
        locations: [ OBJECT ]
    };
    __AppliedDirective applied_bar = {
        args: {
            "name": { value: (), definition: builtInTypes.get(STRING) }
        },
        definition: bar
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.directives.get("bar"), bar);
    test:assertEquals(parsedSchema.queryType.appliedDirectives, [applied_bar]);
 }

@test:Config {
    groups: ["builtin", "applied_directives", "input_values"]
}
function testAppliedDirectiveOnDirectiveDefinitionDependsOnEnum() returns error? { 
    string sdl = check getGraphqlSdlFromFile("applied_directive_on_directive_definition_depends_on_enum");

    __Type status_enum = {
        name: "Status",
        kind: ENUM,
        enumValues: [
            { name: "COMPLETED" },
            { name: "FAILED" }
        ]
    };

    __Directive foo = {
        name: "foo",
        args: {
            "status": { name: "status", 'type: status_enum }
        }, 
        isRepeatable: false,
        locations: [ INPUT_FIELD_DEFINITION ]
    };
    __AppliedDirective applied_foo = {
        args: {
            "status": {
                value: (<__EnumValue[]>status_enum.enumValues)[0],
                definition: status_enum
            }
        },
        definition: foo
    };
    __Directive bar = {
        name: "bar",
        args: {
            "name": { 
                name: "name", 
                appliedDirectives: [applied_foo],
                'type: builtInTypes.get(STRING)
            }
        }, 
        isRepeatable: false,
        locations: [ OBJECT ]
    };
    __AppliedDirective applied_bar = {
        args: {
            "name": { value: (), definition: builtInTypes.get(STRING) }
        },
        definition: bar
    };

    __Schema parsedSchema = check parseSdl(sdl);
    test:assertEquals(parsedSchema.directives.get("bar"), bar);
    test:assertEquals(parsedSchema.queryType.appliedDirectives, [applied_bar]);
 }