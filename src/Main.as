// c 2024-06-21
// m 2024-06-23

dictionary@       accountsById   = dictionary();
dictionary@       accountsByName = dictionary();
string[]          accountsQueue;
const string      audienceCore   = "NadeoServices";
const string      audienceLive   = "NadeoLiveServices";
string            mapUid;
bool              menuOpen       = false;
const float       scale          = UI::GetScale();
SQLite::Database@ timeDB         = SQLite::Database(":memory:");
const string      title          = "\\$FFF" + Icons::Arrows + "\\$G Leaderboard Timestamps";
const uint64      waitTime       = 500;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

class Account {
    string id;
    string name;
    int    score;
    int64  timestamp;

    Account() { }
    Account(const string &in id, int score) {
        this.id = id;
        this.score = score;
    }

    string ToString() {
        return "Account ( id: " + id + ", name: " + name + ", score: " + score + ", ts: " + timestamp + " )";
    }
}

void Main() {
    NadeoServices::AddAudience(audienceCore);
    NadeoServices::AddAudience(audienceLive);

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    while (true) {
        yield();

        menuOpen = false;

        if (App.RootMap is null) {
            accountsById.DeleteAll();
            accountsByName.DeleteAll();
            mapUid = "";
            continue;
        }

        if (accountsQueue.Length > 0) {
            const string accountId = accountsQueue[0];
            const string name = NadeoServices::GetDisplayNameAsync(accountId);
            // print("accountId " + accountId + " has name " + name);
            Account@ account = cast<Account@>(accountsById[accountId]);
            account.name = name;
            accountsByName[name] = @account;
            accountsQueue.RemoveAt(0);
        }
    }
}

void RenderMenu() {
    menuOpen = true;

    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Render() {
    if (
        !S_Enabled
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || (S_HideWithOP && !UI::IsOverlayShown())
        || menuOpen
    )
        return;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null || CMAP.UILayers.Length == 0)
        return;

    if (UI::Begin(title, S_Enabled, UI::WindowFlags::AlwaysAutoResize)) {
        if (UI::Button("get records"))
            startnew(GetTimestampsAsync);

        UI::Text("queue: " + accountsQueue.Length);

        string[]@ names = accountsByName.GetKeys();

        for (uint i = 0; i < names.Length; i++) {
            const string name = names[i];
            Account@ account = cast<Account@>(accountsByName[name]);
            UI::Text(tostring(account));
        }
    }
    UI::End();

    CGameManialinkPage@ RecordsTable;

    for (uint i = 0; i < CMAP.UILayers.Length; i++) {
        CGameUILayer@ Layer = CMAP.UILayers[i];

        if (Layer is null)
            continue;

        if (Layer.ManialinkPageUtf8.Trim().SubStr(26, 11) == "Race_Record") {
            @RecordsTable = Layer.LocalPage;
            break;
        }
    }

    if (RecordsTable is null)
        return;

    CGameManialinkQuad@ Focused = cast<CGameManialinkQuad@>(RecordsTable.FocusedControl);
    if (Focused is null)
        return;

    CGameManialinkFrame@ Parent = cast<CGameManialinkFrame@>(Focused.Parent);
    if (Parent is null)
        return;

    CGameManialinkFrame@ Frame1;
    for (uint i = 0; i < Parent.Controls.Length; i++) {
        CGameManialinkFrame@ Frame = cast<CGameManialinkFrame@>(Parent.Controls[i]);
        if (Frame !is null) {
            @Frame1 = Frame;
            break;
        }
    }
    if (Frame1 is null || Frame1.Controls.Length == 0)
        return;

    CGameManialinkFrame@ Frame2 = cast<CGameManialinkFrame@>(Frame1.Controls[0]);
    if (Frame2 is null || Frame2.Controls.Length == 0)
        return;

    CGameManialinkFrame@ Frame3 = cast<CGameManialinkFrame@>(Frame2.Controls[0]);
    if (Frame3 is null || Frame3.Controls.Length == 0)
        return;

    CGameManialinkLabel@ TheLabel;
    for (uint i = 0; i < Frame3.Controls.Length; i++) {
        CGameManialinkLabel@ Label = cast<CGameManialinkLabel@>(Frame3.Controls[i]);
        if (Label !is null) {
            @TheLabel = Label;
            break;
        }
    }
    if (TheLabel is null)
        return;

    const string name = TheLabel.Value;

    if (name.StartsWith("\u0092"))  // medals
        return;

    const vec2 mousePos = UI::GetMousePos();
    UI::SetNextWindowPos(int((mousePos.x + 5) / scale), int((mousePos.y + 5) / scale), UI::Cond::Always);
    if (UI::Begin(title + "hover", S_Enabled, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoTitleBar)) {
        // UI::Text(name);

        if (accountsByName.Exists(name)) {
            Account@ account = cast<Account@>(accountsByName[name]);
            if (account.timestamp > 0) {
                UI::Text(UnixToIso(account.timestamp));
                UI::Text(FormatSeconds(Time::Stamp - account.timestamp) + " ago");
            } else
                UI::Text("...");
        } else
            UI::Text("...");
    }
    UI::End();
}

void GetTimestampsAsync() {
    accountsById.DeleteAll();
    accountsByName.DeleteAll();
    mapUid = "";

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    if (
        App.RootMap is null
        || App.CurrentPlayground is null
        || App.Editor !is null
    )
        return;

    mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceLive))
        yield();

    GetTopAsync();
    GetSurroundAsync();

    const uint clubId = GetPinnedClubAsync();
    print("pinned club: " + clubId);

    if (clubId > 0) {
        GetClubTopAsync(clubId);
        GetClubSurroundAsync(clubId);
    } else
        print("no pinned club");

    // club vip
    // player vip

    while (!NadeoServices::IsAuthenticated(audienceCore))
        yield();

    GetRecordsAsync();

    print("done");
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
        return days + "d " + hours + "h " + minutes + "m " + seconds + "s";
    if (hours > 0)
        return (day ? "0d " : "") + hours + "h " + minutes + "m " + seconds + "s";
    if (minutes > 0)
        return (day ? "0d " : "") + (hour ? "0h " : "") + minutes + "m " + seconds + "s";
    return (day ? "0d " : "") + (hour ? "0h " : "") + (minute ? "0m " : "") + seconds + "s";
}

Net::HttpRequest@ GetAsync(const string &in audience, const string &in endpoint) {
    Net::HttpRequest@ req = NadeoServices::Get(audience, endpoint);
    req.Start();
    while (!req.Finished())
        yield();

    return req;
}

void GetClubSurroundAsync(uint clubId) {
    sleep(waitTime);
    print("getting club surround");
    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + clubId + "/surround/1/1");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (club surround): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ club = req.Json();
    if (!JsonIsObject(club, "club (surround)"))
        return;

    if (!club.HasKey("top")) {
        warn("club (surround) missing key 'top'");
        return;
    }

    Json::Value@ top = club["top"];
    if (!JsonIsArray(top, "top (club surround)"))
        return;

    if (top.Length == 0)
        warn("top (club surround) is empty");
    else {
        for (uint i = 0; i < top.Length; i++) {
            Json::Value@ clubSurroundRecord = top[i];
            if (!JsonIsObject(clubSurroundRecord, "clubSurroundRecord " + i))
                continue;

            if (!clubSurroundRecord.HasKey("accountId")) {
                warn("clubSurroundRecord " + i + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(clubSurroundRecord["accountId"]);

            if (!clubSurroundRecord.HasKey("score")) {
                warn("clubSurroundRecord " + i + " missing key 'score'");
                continue;
            }

            const int score = int(clubSurroundRecord["score"]);

            // print("accountId " + accountId + " has score " + Time::Format(score));

            if (accountsById.Exists(accountId)) {
                Account@ account = cast<Account@>(accountsById[accountId]);
                account.score = score;
            } else {
                accountsById[accountId] = Account(accountId, score);
                accountsQueue.InsertLast(accountId);
            }
        }
    }
}

void GetClubTopAsync(uint clubId) {
    sleep(waitTime);
    print("getting club top");
    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + clubId + "/top");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (club top): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ club = req.Json();
    if (!JsonIsObject(club, "club (top)"))
        return;

    if (!club.HasKey("top")) {
        warn("club (top) missing key 'top'");
        return;
    }

    Json::Value@ top = club["top"];
    if (!JsonIsArray(top, "top (club top)"))
        return;

    if (top.Length == 0)
        warn("top (club top) is empty");
    else {
        for (uint i = 0; i < top.Length; i++) {
            Json::Value@ clubTopRecord = top[i];
            if (!JsonIsObject(clubTopRecord, "clubTopRecord " + i))
                continue;

            if (!clubTopRecord.HasKey("accountId")) {
                warn("clubTopRecord " + i + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(clubTopRecord["accountId"]);

            if (!clubTopRecord.HasKey("score")) {
                warn("clubTopRecord " + i + " missing key 'score'");
                continue;
            }

            const int score = int(clubTopRecord["score"]);

            // print("accountId " + accountId + " has score " + Time::Format(score));

            if (accountsById.Exists(accountId)) {
                Account@ account = cast<Account@>(accountsById[accountId]);
                account.score = score;
            } else {
                accountsById[accountId] = Account(accountId, score);
                accountsQueue.InsertLast(accountId);
            }
        }
    }
}

Net::HttpRequest@ GetCoreAsync(const string &in endpoint) {
    return GetAsync(audienceCore, NadeoServices::BaseURLCore() + endpoint);
}

Net::HttpRequest@ GetLiveAsync(const string &in endpoint) {
    return GetAsync(audienceLive, NadeoServices::BaseURLLive() + endpoint);
}

string GetMapIdAsync() {
    sleep(waitTime);
    print("getting mapId");
    Net::HttpRequest@ req = GetCoreAsync("/maps/?mapUidList=" + mapUid);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (map info): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return "";
    }

    Json::Value@ mapInfo = req.Json();
    if (!JsonIsArray(mapInfo, "mapInfo"))
        return "";

    if (mapInfo.Length == 0) {
        warn("mapInfo is empty");
        return "";
    }

    Json::Value@ map = mapInfo[0];
    if (!JsonIsObject(map, "map"))
        return "";

    if (!map.HasKey("mapId")) {
        warn("map missing key 'mapId'");
        return "";
    }

    return string(map["mapId"]);
}

uint GetPinnedClubAsync() {
    sleep(waitTime);
    print("getting pinned club");
    Net::HttpRequest@ req = GetLiveAsync("/api/token/club/player/info");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (pinned club): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return 0;
    }

    Json::Value@ clubInfo = req.Json();
    if (!JsonIsObject(clubInfo, "pinned club"))
        return 0;

    if (!clubInfo.HasKey("pinnedClub")) {
        warn("clubInfo missing key 'pinnedClub'");
        return 0;
    }

    return uint(clubInfo["pinnedClub"]);
}

void GetRecordsAsync() {
    const string mapId = GetMapIdAsync();
    if (mapId.Length == 0) {
        warn("mapId empty");
        return;
    }

    sleep(waitTime);
    print("getting records");
    Net::HttpRequest@ req = GetCoreAsync("/mapRecords/?accountIdList=" + string::Join(accountsById.GetKeys(), "%2C") + "&mapIdList=" + mapId);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (records): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ records = req.Json();
    if (!JsonIsArray(records, "records"))
        return;

    if (records.Length == 0) {
        warn("records is empty");
        return;
    }

    for (uint i = 0; i < records.Length; i++) {
        Json::Value@ record = records[i];
        if (!JsonIsObject(record, "record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn("record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = record["accountId"];

        if (!record.HasKey("timestamp")) {
            warn("record " + i + " missing key 'timestamp'");
            continue;
        }

        const string timestampIso = string(record["timestamp"]);
        const int64 timestamp = IsoToUnix(timestampIso);

        Account@ account = cast<Account@>(accountsById[accountId]);
        account.timestamp = timestamp;
        // print(account);
    }
}

void GetSurroundAsync() {
    sleep(waitTime);
    print("getting surround");
    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (surround): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ top = req.Json();
    if (!JsonIsObject(top, "top"))
        return;

    if (!top.HasKey("tops")) {
        warn("top (surround) missing key 'tops'");
        return;
    }

    Json::Value@ tops = top["tops"];
    if (!JsonIsArray(tops, "tops"))
        return;

    if (tops.Length == 0)
        warn("tops (surround) is empty");
    else {
        for (uint i = 0; i < tops.Length; i++) {
            Json::Value@ region = tops[i];
            if (!JsonIsObject(region, "region " + i))
                continue;

            if (!region.HasKey("top")) {
                warn("region " + i + " (surround) missing key 'top'");
                continue;
            }

            Json::Value@ regionTop = region["top"];
            if (!JsonIsArray(regionTop, "regionTop"))
                continue;

            for (uint j = 0; j < regionTop.Length; j++) {
                Json::Value@ regionTopRecord = regionTop[j];
                if (!JsonIsObject(regionTopRecord, "regionTopRecord " + i + " " + j))
                    continue;

                if (!regionTopRecord.HasKey("accountId")) {
                    warn("regionTopRecord " + i + " " + j + " (surround) missing key 'accountId'");
                    continue;
                }

                const string accountId = string(regionTopRecord["accountId"]);

                if (!regionTopRecord.HasKey("score")) {
                    warn("regionTopRecord " + i + " " + j + " (surround) missing key 'score'");
                    continue;
                }

                const int score = int(regionTopRecord["score"]);

                // print("accountId " + accountId + " has score " + Time::Format(score));

                if (accountsById.Exists(accountId)) {
                    Account@ account = cast<Account@>(accountsById[accountId]);
                    account.score = score;
                } else {
                    accountsById[accountId] = Account(accountId, score);
                    accountsQueue.InsertLast(accountId);
                }
            }
        }
    }

}

void GetTopAsync() {
    sleep(waitTime);
    print("getting top");
    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (top): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ top = req.Json();
    if (!JsonIsObject(top, "top"))
        return;

    if (!top.HasKey("tops")) {
        warn("top missing key 'tops'");
        return;
    }

    Json::Value@ tops = top["tops"];
    if (!JsonIsArray(tops, "tops"))
        return;

    if (tops.Length == 0) {
        warn("tops is empty");
        return;
    }

    for (uint i = 0; i < tops.Length; i++) {
        Json::Value@ region = tops[i];
        if (!JsonIsObject(region, "region " + i))
            continue;

        if (!region.HasKey("top")) {
            warn("region " + i + " missing key 'top'");
            continue;
        }

        Json::Value@ regionTop = region["top"];
        if (!JsonIsArray(regionTop, "regionTop"))
            continue;

        for (uint j = 0; j < regionTop.Length; j++) {
            Json::Value@ regionTopRecord = regionTop[j];
            if (!JsonIsObject(regionTopRecord, "regionTopRecord " + i + " " + j))
                continue;

            if (!regionTopRecord.HasKey("accountId")) {
                warn("regionTopRecord " + i + " " + j + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(regionTopRecord["accountId"]);

            if (!regionTopRecord.HasKey("score")) {
                warn("regionTopRecord " + i + " " + j + " missing key 'score'");
                continue;
            }

            const int score = int(regionTopRecord["score"]);

            // print("accountId " + accountId + " has score " + Time::Format(score));

            if (accountsById.Exists(accountId)) {
                Account@ account = cast<Account@>(accountsById[accountId]);
                account.score = score;
            } else {
                accountsById[accountId] = Account(accountId, score);
                accountsQueue.InsertLast(accountId);
            }
        }
    }
}

// courtesy of MisfitMaid
int64 IsoToUnix(const string &in inTime) {
    SQLite::Statement@ s = timeDB.Prepare("SELECT unixepoch(?) as x");
    s.Bind(1, inTime);
    s.Execute();
    s.NextRow();
    s.NextRow();
    return s.GetColumnInt64("x");
}

bool JsonIsArray(Json::Value@ value, const string &in name) {
    return CheckJsonType(value, Json::Type::Array, name);
}

bool JsonIsObject(Json::Value@ value, const string &in name) {
    return CheckJsonType(value, Json::Type::Object, name);
}

string UnixToIso(uint timestamp) {
    return Time::FormatString("%Y-%m-%d \\$AAA@ \\$G%H:%M:%S \\$AAA(%a)\\$G", timestamp);
}
