public type WRAPPING_TYPE NON_NULL | LIST;
public isolated function wrapType(__Type 'type, WRAPPING_TYPE kind) returns __Type {
    return {
        kind: kind,
        ofType: 'type
    };
}
