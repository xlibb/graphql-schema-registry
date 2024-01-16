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
