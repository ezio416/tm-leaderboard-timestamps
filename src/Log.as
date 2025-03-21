// c 2025-03-20
// m 2025-03-20

[Setting category="Logging" name="Log level" description="Debug spams the log but is helpful for troubleshooting."]
Log::Level S_LogLevel = Log::Level::Debug;

namespace Log {
    enum Level {
        Error,
        Warning,
        Info,
        Debug
    }

    void Debug(const string &in msg, const string &in funcName = "") {
        if (S_LogLevel >= Level::Debug)
            print((funcName.Length > 0 ? DARKGRAY + funcName + ": " + RESET : "") + msg);
    }

    void Error(const string &in msg, const string &in funcName = "") {
        error((funcName.Length > 0 ? DARKGRAY + funcName + ": " : "") + msg);
    }

    void Info(const string &in msg, const string &in funcName = "") {
        if (S_LogLevel >= Level::Info)
            trace((funcName.Length > 0 ? DARKGRAY + funcName + ": " : "") + msg);
    }

    void Warn(const string &in msg, const string &in funcName = "") {
        if (S_LogLevel >= Level::Warning)
            warn((funcName.Length > 0 ? DARKGRAY + funcName + ": " : "") + msg);
    }
}
