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

isolated function createMergeErrorMessages(MergeError[] errors) returns InternalError|MergeError[] {
    MergeError[] transformedErrors = [];
    foreach MergeError inputError in errors {
        MergeError|InternalError transformedError = createMergeErrorMessage(inputError);
        if transformedError is MergeError {
            transformedErrors.push(transformedError);
        } else {
            return transformedError;
        }
    }
    return transformedErrors;
}

isolated function createMergeErrorMessage(MergeError 'error) returns InternalError|MergeError {
    Hint? hint = 'error.detail().hint;
    if hint is Hint {
        return error MergeError(printHint(hint), hint = hint);
    } else {
        return error InternalError("Hints not found for MergeError");
    }
}