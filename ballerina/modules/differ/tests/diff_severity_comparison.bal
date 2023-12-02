import ballerina/test;

@test:Config {
    groups: ["differ"],
    dataProvider: dataProviderTestDiffSeverity
}
function testDiffSeverity(DiffSeverity[] severities, DiffSeverity expected) returns error? {
    test:assertEquals(getMajorSeverity(severities), expected);
}

function dataProviderTestDiffSeverity() returns [DiffSeverity[], DiffSeverity][] {
    return [
        [[SAFE, SAFE, SAFE], SAFE],
        [[SAFE, SAFE, DANGEROUS], DANGEROUS],
        [[SAFE], SAFE],
        [[DANGEROUS], DANGEROUS],
        [[BREAKING], BREAKING],
        [[SAFE, DANGEROUS], DANGEROUS],
        [[SAFE, SAFE, SAFE], SAFE],
        [[SAFE, SAFE, SAFE], SAFE],
        [[SAFE, SAFE, DANGEROUS], DANGEROUS],
        [[BREAKING, SAFE, DANGEROUS], BREAKING],
        [[SAFE, SAFE, SAFE, SAFE], SAFE],
        [[SAFE, BREAKING, DANGEROUS, SAFE], BREAKING],
        [[SAFE, DANGEROUS, DANGEROUS, SAFE, DANGEROUS, BREAKING], BREAKING],
        [[BREAKING, BREAKING, BREAKING, BREAKING], BREAKING],
        [[DANGEROUS, DANGEROUS, DANGEROUS, DANGEROUS], DANGEROUS],
        [[BREAKING, BREAKING, DANGEROUS, BREAKING], BREAKING],
        [[DANGEROUS, SAFE, BREAKING, SAFE], BREAKING],
        [[DANGEROUS, BREAKING, DANGEROUS, DANGEROUS], BREAKING]
    ];
}

