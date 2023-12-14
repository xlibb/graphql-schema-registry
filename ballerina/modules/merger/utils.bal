public isolated function printSubgraphs(string[] subgraphs) returns string {
    if subgraphs.length() == 0 {
        return "";
    } else if subgraphs.length() == 1 {
        return string `"${subgraphs[0]}"`;
    } else {
        string[]|error clonedSubgraphs = subgraphs.cloneWithType();
        if clonedSubgraphs is error {
            return "";
        }
        string last = clonedSubgraphs.pop();
        return string `${string:'join(", ", ...clonedSubgraphs.map(s => string `"${s}"`))} and "${last}"`;
    }
}