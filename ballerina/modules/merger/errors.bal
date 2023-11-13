public type Error distinct error;

public type InternalError distinct Error;

public type MergeError distinct (Error & error<record {| Hint hint; |}>);