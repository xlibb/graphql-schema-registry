type ComparisionResult record {|
    string[] added;
    string[] removed;
    string[] common;
|};

public type SchemaDiff record {|
    DiffSeverity severity;
    DiffAction action;
    DiffSubject subject;
    string[] location;
    string? value;
    string? fromValue;
    string? toValue;
|};

public enum TypeKind {
    OBJECT,
    INTERFACE,
    FIELD,
    ARGUMENT,
    INPUT_OBJECT,
    INPUT_FIELD,
    UNION,
    ENUM,
    ENUM_VALUE,
    SCALAR
}

public enum DiffSeverity {
    BREAKING,
    DANGEROUS,
    SAFE
}

public enum DiffAction {
    ADDED,
    REMOVED,
    CHANGED
}

public enum DiffSubject {
    DIRECTIVE,
    TYPE,
    TYPE_KIND,
    TYPE_DESCRIPTION,
    FIELD,
    FIELD_DEPRECATION,
    FIELD_TYPE,
    ARGUMENT,
    ARGUMENT_TYPE,
    ARGUMENT_DEFAULT,
    INPUT_FIELD,
    INPUT_FIELD_DEFAULT,
    INPUT_FIELD_TYPE,
    ENUM,
    ENUM_DEPRECATION,
    INTERFACE_IMPLEMENTATION
}