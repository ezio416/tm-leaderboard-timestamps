bool AlwaysDisplayRecords() {
    auto App = cast<CTrackMania>(GetApp());

    if (false
        or App.CurrentProfile is null
        or !App.CurrentProfile.Interface_AlwaysDisplayRecords
    ) {
        return false;
    }

    return true;
}

void CancelAsync() {
    if (getting) {
        warn("already getting records, canceling...");
        cancel = true;
    }

    while (getting) {
        // warn("still getting...");
        yield();
    }
}

bool CheckJsonType(Json::Value@ value, Json::Type desired, const string&in name) {
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

    if (days > 0) {
        return days + "d" + (!S_RecencyLargest ? " " + hours + "h " + minutes + "m " + seconds + "s" : "");
    }
    if (hours > 0) {
        return (day ? "0d " : "") + hours + "h" + (!S_RecencyLargest ? " " + minutes + "m " + seconds + "s" : "");
    }
    if (minutes > 0) {
        return (day ? "0d " : "") + (hour ? "0h " : "") + minutes + "m" + (!S_RecencyLargest ? " " + seconds + "s" : "");
    }
    return (day ? "0d " : "") + (hour ? "0h " : "") + (minute ? "0m " : "") + seconds + "s";
}

void GetTimestampsAsync() {
    const bool surround = onlySurround;
    if (surround) {
        onlySurround = false;
    }

    if (getting) {
        // warn("already getting");
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
        if (false
            or cancel
            or !InMap()
        ) {
            cancel = false;
            getting = false;
            return;
        }
    }

    GetRegionsSurroundAsync();
    if (false
        or cancel
        or !InMap()
    ) {
        cancel = false;
        getting = false;
        return;
    }

    GetPlayerClubInfoAsync();
    if (false
        or cancel
        or !InMap()
    ) {
        cancel = false;
        getting = false;
        return;
    }

    GetClubSurroundAsync();
    if (false
        or cancel
        or !InMap()
    ) {
        cancel = false;
        getting = false;
        return;
    }

    if (!surround) {
        GetClubTopAsync();
        if (false
            or cancel
            or !InMap()
        ) {
            cancel = false;
            getting = false;
            return;
        }

        GetClubVIPsAsync();
        if (false
            or cancel
            or !InMap()
        ) {
            cancel = false;
            getting = false;
            return;
        }

        GetPlayerVIPsAsync();
        if (false
            or cancel
            or !InMap()
        ) {
            cancel = false;
            getting = false;
            return;
        }
    }

    while (!NadeoServices::IsAuthenticated(audienceCore)) {
        yield();
    }

    GetRecordsAsync();
    if (cancel) {
        cancel = false;
        getting = false;
        return;
    }

    GetServerPlayerPBAsync();

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
        or CMAP is null
        or CMAP.ScoreMgr is null
        or App.RootMap is null
        or App.UserManagerScript is null
        or App.UserManagerScript.Users.Length == 0
        or App.UserManagerScript.Users[0] is null
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
    if (!InMap()) {
        return 0;
    }

    auto App = cast<CTrackMania>(GetApp());
    auto Network = cast<CTrackManiaNetwork>(App.Network);
    auto CMAP = Network.ClientManiaAppPlayground;

    if (false
        or CMAP is null
        or CMAP.ScoreMgr is null
        or CMAP.UI is null
        or CMAP.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::Finish
        or App.UserManagerScript is null
        or App.UserManagerScript.Users.Length == 0
        or App.UserManagerScript.Users[0] is null
    ) {
        return 0;
    }

    sleep(500);  // allow game to process PB, 500ms should be enough time

    return GetPersonalBest();
}

void HoverTooltip(const string&in msg) {
    if (!UI::IsItemHovered()) {
        return;
    }

    UI::BeginTooltip();
    UI::Text(msg);
    UI::EndTooltip();
}

bool InMap() {
    CGameCtnApp@ App = GetApp();

    return true
        and App.RootMap !is null
        and App.Editor is null
        and cast<CSmArenaClient>(App.CurrentPlayground) !is null
    ;
}

bool JsonIsArray(Json::Value@ value, const string&in name) {
    return CheckJsonType(value, Json::Type::Array, name);
}

bool JsonIsObject(Json::Value@ value, const string&in name) {
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
    return !Regex::Contains(S_TimestampFormat, "(%[^aAbBcCdDeFgGhHIjmMnprRStTuUVwWxXyYzZ%])|([^%]%(%%)*$)");
}
