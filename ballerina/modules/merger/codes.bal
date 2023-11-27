enum HintCode {
    INCONSISTENT_DESCRIPTION,
    INCONSISTENT_BUT_COMPATIBLE_OUTPUT_TYPE,
    INCONSISTENT_BUT_COMPATIBLE_INPUT_TYPE,
    INCONSISTENT_UNION_MEMBER,
    INCONSISTENT_ARGUMENT_PRESENCE,
    INCONSISTENT_DEFAULT_VALUE_PRESENCE
}

enum ErrorCode {
    REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH,
    DEFAULT_VALUE_MISMATCH,
    OUTPUT_TYPE_MISMATCH,
    INPUT_TYPE_MISMATCH,
    FIELD_ARGUMENT_TYPE_MISMATCH,
    TYPE_KIND_MISMATCH
}