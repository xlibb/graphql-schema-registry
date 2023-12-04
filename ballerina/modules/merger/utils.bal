isolated function appendErrors(MergeError[] newErrors, MergeError[] errors, string? location = ()) returns InternalError? {
    MergeError[] updatedErrors = errors;
    if location is string {
        updatedErrors = [];
        foreach MergeError mergeError in errors {
            Hint|error hint = mergeError.detail().hint.cloneWithType(Hint);
            if hint is error {
                return error InternalError("MergeError hint is null");
            }
            addHintLocation(hint, location);
            updatedErrors.push(error MergeError(mergeError.message(), hint = hint));
        }
    }
    newErrors.push(...updatedErrors);
}

isolated function appendHints(Hint[] newHints, Hint[] mergeHints, string? location = ()) {
    addHintsLocation(mergeHints, location);
    newHints.push(...mergeHints);
}

isolated function addHintsLocation(Hint[] hints, string? location = ()) {
    if location !is () {
        foreach Hint hint in hints {
            addHintLocation(hint, location);
        }
    }
}

isolated function addHintLocation(Hint hint, string location) {
    hint.location.unshift(location);
}

isolated function printHints(Hint[] hints) returns string[] {
    string[] hintMessages = [];
    foreach Hint hint in hints {
        hintMessages.push(printHint(hint));
    }
    return hintMessages;
}

isolated function printHint(Hint hint) returns string {
    return string `${hint.code}: ${string:'join(".", ...hint.location)}, ${string:'join(", ", ...hint.details.'map(h => printHintDetail(h)))}`;
}

isolated function printHintDetail(HintDetail hintDetail) returns string {
    string hintDetailStr = string `Found '${hintDetail.value.toString()}' in ${string:'join(", ", ...(hintDetail.consistentSubgraphs))}`;
    if hintDetail.inconsistentSubgraphs.length() > 0 {
        hintDetailStr += ", but not in ";
        hintDetailStr += string:'join(", ", ...(hintDetail.inconsistentSubgraphs));
    }
    return hintDetailStr;
}

isolated function addMergeErrorMessages(MergeError[] errors) returns InternalError|MergeError[] {
    MergeError[] transformedErrors = [];
    foreach MergeError inputError in errors {
        MergeError|InternalError transformedError = addMergeErrorMessage(inputError);
        if transformedError is MergeError {
            transformedErrors.push(transformedError);
        } else {
            return transformedError;
        }
    }
    return transformedErrors;
}

isolated function addMergeErrorMessage(MergeError 'error) returns InternalError|MergeError {
    Hint? hint = 'error.detail().hint;
    if hint is Hint {
        return error MergeError(printHint(hint), hint = hint);
    } else {
        return error InternalError("Hints not found for MergeError");
    }
}