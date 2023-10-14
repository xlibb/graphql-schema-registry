import ballerina/jballerina.java;

isolated function init() {
    setModule();
}

isolated function setModule() = @java:Method {
    'class: "io.xlibb.schemaregistry.utils.ModuleUtils"
} external;