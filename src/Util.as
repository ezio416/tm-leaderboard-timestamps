// c 2024-06-24
// m 2025-03-19

bool AlwaysDisplayRecords() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    if (App.CurrentProfile is null || !App.CurrentProfile.Interface_AlwaysDisplayRecords)
        return false;

    return true;
}

bool CheckJsonType(Json::Value@ value, Json::Type desired, const string &in name) {
    if (value is null) {
        warn(name + " is null");
        return false;
    }

    const Json::Type type = value.GetType();
    if (type != desired) {
        warn(name + " is a(n) " + tostring(type) + ", not a(n) " + tostring(desired));
        return false;
    }

    return true;
}

string FormatSeconds(int seconds, bool day = false, bool hour = false, bool minute = false) {
    int minutes = seconds / 60;
    seconds %= 60;
    int hours = minutes / 60;
    minutes %= 60;
    int days = hours / 24;
    hours %= 24;

    if (days > 0)
        return days + "d" + (!S_RecencyLargest ? " " + hours + "h " + minutes + "m " + seconds + "s" : "");
    if (hours > 0)
        return (day ? "0d " : "") + hours + "h" + (!S_RecencyLargest ? " " + minutes + "m " + seconds + "s" : "");
    if (minutes > 0)
        return (day ? "0d " : "") + (hour ? "0h " : "") + minutes + "m" + (!S_RecencyLargest ? " " + seconds + "s" : "");
    return (day ? "0d " : "") + (hour ? "0h " : "") + (minute ? "0m " : "") + seconds + "s";
}

uint GetPersonalBestAsync() {
    if (!InMap())
        return 0;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (false
        || CMAP is null
        || CMAP.ScoreMgr is null
        || CMAP.UI is null
        || CMAP.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::Finish
        || App.UserManagerScript is null
        || App.UserManagerScript.Users.Length == 0
        || App.UserManagerScript.Users[0] is null
    )
        return 0;

    sleep(500);  // allow game to process PB, 500ms should be enough time

    if (false
        || CMAP is null
        || CMAP.ScoreMgr is null
        || App.UserManagerScript is null
        || App.UserManagerScript.Users.Length == 0
        || App.UserManagerScript.Users[0] is null
    )
        return 0;

    return CMAP.ScoreMgr.Map_GetRecord_v2(App.UserManagerScript.Users[0].Id, mapUid, "PersonalBest", "", "TimeAttack", "");
}

void HoverTooltip(const string &in msg) {
    if (!UI::IsItemHovered())
        return;

    UI::BeginTooltip();
        UI::Text(msg);
    UI::EndTooltip();
}

bool InMap() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    return App.RootMap !is null
        && App.CurrentPlayground !is null
        && App.Editor is null;
}

bool JsonIsArray(Json::Value@ value, const string &in name) {
    return CheckJsonType(value, Json::Type::Array, name);
}

bool JsonIsObject(Json::Value@ value, const string &in name) {
    return CheckJsonType(value, Json::Type::Object, name);
}

// prevents some crashes
string TimeFormatString(const string &in format, int64 stamp = -1) {
    if (format.Contains("% ") || format.Trim().EndsWith("%"))
        return "ERROR";

    return Time::FormatString(format, stamp);
}

string UnixToIso(uint timestamp) {
    return TimeFormatString(S_TimestampFormat.Replace("$", "\\$"), timestamp);
}
