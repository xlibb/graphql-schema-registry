package io.xlibb.schemaregistry.utils;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Module;

public class ModuleUtils {
    
    private static Module module;

    private ModuleUtils () {}

    public static void setModule(Environment environment) {
        module = environment.getCurrentModule();
    }

    public static Module getModule() {
        return module;
    }
}
