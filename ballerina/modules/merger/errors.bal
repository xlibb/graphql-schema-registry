type MergeErrorDetail record {|
    string reason;
    string code;
|};

public type Error distinct error;

public type InternalError distinct Error;

public type MergeError distinct (Error & error<MergeErrorDetail>);

public type FatalMergeError distinct MergeError;
public type ResilientMergeError distinct MergeError;