import ballerina/io;

function appendHints(Hint[] newHints, Hint[] mergeHints, string location) {
    addHintsLocation(mergeHints, location);
    newHints.push(...mergeHints);
}

function addHintsLocation(Hint[] hints, string location) {
    foreach Hint hint in hints {
        hint.location.unshift(location);
    }
}

function printHints(Hint[] hints) {
    foreach Hint hint in hints {
        io:println(string `${hint.code}: ${string:'join(".", ...hint.location)}, ${string:'join(", ", ...hint.details.'map(h => printHintDetail(h)))}`);
    }
}

function printHintDetail(HintDetail hintDetail) returns string {
    string hintDetailStr = string `Found '${hintDetail.value.toString()}' in ${string:'join(", ", ...(hintDetail.consistentSubgraphs.'map(s => s.name)))}`;
    if hintDetail.inconsistentSubgraphs.length() > 0 {
        hintDetailStr += ", but not in ";
        hintDetailStr += string:'join(", ", ...(hintDetail.inconsistentSubgraphs.'map(s => s.name)));
    }
    return hintDetailStr;
}