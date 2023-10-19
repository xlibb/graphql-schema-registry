public type Error distinct error;

public type InternalError distinct Error;

public type MergeError distinct Error;

public type FatalMergeError distinct MergeError;
public type ResilientMergeError distinct MergeError;