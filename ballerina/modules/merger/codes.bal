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

enum HintCode {
    INCONSISTENT_DESCRIPTION,
    INCONSISTENT_BUT_COMPATIBLE_OUTPUT_TYPE,
    INCONSISTENT_BUT_COMPATIBLE_INPUT_TYPE,
    INCONSISTENT_UNION_MEMBER,
    INCONSISTENT_ARGUMENT_PRESENCE,
    INCONSISTENT_DEFAULT_VALUE_PRESENCE,
    INCONSISTENT_TYPE_FIELD // <= Can be either INTEFACE or OBJECT
}

enum ErrorCode {
    REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH,
    DEFAULT_VALUE_MISMATCH,
    OUTPUT_TYPE_MISMATCH,
    INPUT_TYPE_MISMATCH,
    FIELD_ARGUMENT_TYPE_MISMATCH,
    TYPE_KIND_MISMATCH,
    INVALID_FIELD_SHARING,
    ENUM_VALUE_MISMATCH
}
