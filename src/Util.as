// c 2024-06-24
// m 2025-08-01

bool AlwaysDisplayRecords() {
    auto App = cast<CTrackMania>(GetApp());

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

void GetTimestampsAsync() {
    const bool surround = onlySurround;
    if (surround) {
        onlySurround = false;
    }

    if (getting) {
        return;
    }

    const string funcName = "GetTimestampsAsync";
    trace(funcName + ": starting");
    getting = true;

    if (!surround) {
        Reset();
    }

    if (!InMap()) {
        getting = false;
        pb = 0;
        return;
    }

    auto App = cast<CTrackMania>(GetApp());

    const string mapType = string(App.RootMap.MapType);
    if (false
        or mapType.Contains("TM_Platform")
        or mapType.Contains("TM_Royal")
    ) {
        warn(funcName + ": bad map type (" + mapType + ")");
        getting = false;
        return;
    }

    mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceLive)) {
        yield();
    }

    // if (medalGhosts.GetSize() == 0)
    //     GetMedalGhostsAsync();  // problem if a top record is a medal ghost, todo later

    if (!surround) {
        GetRegionsTopAsync();
        if (!InMap()) {
            getting = false;
            return;
        }
    }

    GetRegionsSurroundAsync();
    if (!InMap()) {
        getting = false;
        return;
    }

    GetPlayerClubInfoAsync();
    if (!InMap()) {
        getting = false;
        return;
    }

    GetClubSurroundAsync();
    if (!InMap()) {
        getting = false;
        return;
    }

    if (!surround) {
        GetClubTopAsync();
        if (!InMap()) {
            getting = false;
            return;
        }

        GetClubVIPsAsync();
        if (!InMap()) {
            getting = false;
            return;
        }

        GetPlayerVIPsAsync();
        if (!InMap()) {
            getting = false;
            return;
        }
    }

    while (!NadeoServices::IsAuthenticated(audienceCore)) {
        yield();
    }

    GetRecordsAsync();

    trace(funcName + ": success");
    getting = false;
}

uint GetPersonalBest() {
    if (!InMap()) {
        warn("not in map");
        return 0;
    }

    auto App = cast<CTrackMania>(GetApp());
    auto Network = cast<CTrackManiaNetwork>(App.Network);
    auto CMAP = Network.ClientManiaAppPlayground;

    if (false
        || CMAP is null
        || CMAP.ScoreMgr is null
        || App.RootMap is null
        || App.UserManagerScript is null
        || App.UserManagerScript.Users.Length == 0
        || App.UserManagerScript.Users[0] is null
    ) {
        warn("something wrong");
        return 0;
    }

    return CMAP.ScoreMgr.Map_GetRecord_v2(
        App.UserManagerScript.Users[0].Id,
        App.RootMap.EdChallengeId,
        "PersonalBest",
        "",
        "TimeAttack",
        ""
    );
}

uint GetPersonalBestAsync() {
    if (!InMap())
        return 0;

    auto App = cast<CTrackMania>(GetApp());
    auto Network = cast<CTrackManiaNetwork>(App.Network);
    auto CMAP = Network.ClientManiaAppPlayground;

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

    return GetPersonalBest();
}

void HoverTooltip(const string &in msg) {
    if (!UI::IsItemHovered())
        return;

    UI::BeginTooltip();
        UI::Text(msg);
    UI::EndTooltip();
}

bool InMap() {
    auto App = cast<CTrackMania>(GetApp());

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

void Reset() {
    // accountsById.DeleteAll();  // don't delete all now that we support medals
    // accountsByName.DeleteAll();
    accountsQueue   = {};
    hasClubVip      = false;
    hasPlayerVip    = false;
    // lastUid         = "";
    mapUid          = "";
    newLocalPb      = false;
    // pb              = 0;
    pinnedClub      = 0;
    raceRecordIndex = -1;

    string[]@ ids = accountsById.GetKeys();
    string id;
    for (uint i = 0; i < ids.Length; i++) {
        id = ids[i];

        auto account = cast<Account>(accountsById[id]);
        if (account is null) {
            accountsById.Delete(id);
            continue;
        }

        if (!account.name.StartsWith("\u0092")) {
            accountsById.Delete(id);

            if (accountsByName.Exists(account.name)) {
                accountsByName.Delete(account.name);
            }
        }
    }
}

string TimeFormatString(const string&in format, const int64 stamp = -1) {
    return timeFormatValid ? Time::FormatString(format, stamp) : "FORMAT ERROR";
}

string UnixToIso(uint timestamp) {
    return TimeFormatString(
        S_Legacy
            ? Text::OpenplanetFormatCodes(S_TimestampFormat)
            : Text::StripFormatCodes(S_TimestampFormat)
        ,
        timestamp
    );
}

// prevents most crashes
bool VerifyTimeFormat() {
    if (true
        and S_TimestampFormat.EndsWith("%")
        and !S_TimestampFormat.EndsWith("%%")
    ) {
        return false;
    }

    Regex::SearchAllResult@ results = Regex::SearchAll(S_TimestampFormat, "%[^aAbBcCdDeFgGhHIjmMnprRStTuUVwWxXyYzZ]");
    for (uint i = 0; i < results.Length; i++) {
        for (uint j = 0; j < results[i].Length; j++) {
            if (!results[i][j].Contains("%%")) {
                return false;
            }
        }
    }

    return true;
}
