// c 2024-06-21
// m 2024-06-24

dictionary@       accountsById   = dictionary();
dictionary@       accountsByName = dictionary();
string[]          accountsQueue;
const string      audienceCore   = "NadeoServices";
const string      audienceLive   = "NadeoLiveServices";
bool              getting        = false;
bool              hasClubVip     = false;
bool              hasPlayerVip   = false;
string            mapUid;
bool              menuOpen       = false;
uint              pinnedClub     = 0;
const float       scale          = UI::GetScale();
SQLite::Database@ timeDB         = SQLite::Database(":memory:");
const string      title          = "\\$0AF" + Icons::ListOl + "\\$G Leaderboard Timestamps";
const uint64      waitTime       = 500;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

class Account {
    string id;
    string name;
    int64  timestamp;

    Account() { }
    Account(const string &in id) {
        this.id = id;
    }

    string ToString() {
        return "Account ( id: " + id + ", name: " + name + ", ts: " + timestamp + " )";
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
            Reset();
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

    if (UI::BeginMenu(title)) {
        if (UI::MenuItem(Icons::Check + " Enabled", "", S_Enabled))
            S_Enabled = !S_Enabled;

        if (UI::MenuItem((getting ? "\\$AAA" : "") + Icons::Refresh + " Force Refresh", "", false, !getting))
            startnew(GetTimestampsAsync);

        UI::EndMenu();
    }
}

void Render() {
    if (!S_Enabled || (S_HideWithOP && !UI::IsOverlayShown()))
        return;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null || CMAP.UILayers.Length == 0)
        return;

    // if (UI::Begin(title, S_Enabled, UI::WindowFlags::AlwaysAutoResize)) {
    //     if (UI::Button("get records"))
    //         startnew(GetTimestampsAsync);

    //     UI::Text("queue: " + accountsQueue.Length);

    //     string[]@ names = accountsByName.GetKeys();

    //     for (uint i = 0; i < names.Length; i++) {
    //         const string name = names[i];
    //         Account@ account = cast<Account@>(accountsByName[name]);
    //         UI::Text(tostring(account));
    //     }
    // }
    // UI::End();

    if (menuOpen)
        return;

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
    while (getting)
        yield();

    const string funcName = "GetTimestampsAsync";
    trace(funcName + ": starting");
    getting = true;

    Reset();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    if (
        App.RootMap is null
        || App.CurrentPlayground is null
        || App.Editor !is null
    ) {
        getting = false;
        return;
    }

    mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceLive))
        yield();

    GetTopAsync();
    GetSurroundAsync();
    GetPlayerClubInfoAsync();
    GetClubTopAsync();
    GetClubSurroundAsync();
    GetClubVIPsAsync();
    GetPlayerVIPsAsync();

    while (!NadeoServices::IsAuthenticated(audienceCore))
        yield();

    GetRecordsAsync();

    trace(funcName + ": success");
    getting = false;
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
    sleep(waitTime);

    Net::HttpRequest@ req = NadeoServices::Get(audience, endpoint);
    req.Start();
    while (!req.Finished())
        yield();

    return req;
}

void GetClubSurroundAsync() {
    if (pinnedClub == 0)
        return;

    const string funcName = "GetClubSurroundAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/surround/1/1");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("top")) {
        warn(funcName + ": parsed missing key 'top'");
        return;
    }

    Json::Value@ top = parsed["top"];
    if (!JsonIsArray(top, funcName + ": top"))
        return;

    if (top.Length == 0) {
        warn(funcName + ": top is empty");
        return;
    }

    for (uint i = 0; i < top.Length; i++) {
        Json::Value@ record = top[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn(funcName + ": record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = string(record["accountId"]);

        if (!accountsById.Exists(accountId)) {
            accountsById[accountId] = Account(accountId);
            accountsQueue.InsertLast(accountId);
        }
    }

    trace(funcName + ": success");
}

void GetClubTopAsync() {
    if (pinnedClub == 0)
        return;

    const string funcName = "GetClubTopAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/top");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("top")) {
        warn(funcName + ": parsed missing key 'top'");
        return;
    }

    Json::Value@ top = parsed["top"];
    if (!JsonIsArray(top, funcName + ": top"))
        return;

    if (top.Length == 0) {
        warn(funcName + ": top is empty");
        return;
    }

    for (uint i = 0; i < top.Length; i++) {
        Json::Value@ record = top[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn(funcName + ": record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = string(record["accountId"]);

        if (!accountsById.Exists(accountId)) {
            accountsById[accountId] = Account(accountId);
            accountsQueue.InsertLast(accountId);
        }
    }

    trace(funcName + ": success");
}

void GetClubVIPsAsync() {
    if (pinnedClub == 0 || !hasClubVip)
        return;

    GetVIPsAsync("GetClubVIPsAsync", "/api/token/club/" + pinnedClub + "/vip/map/" + mapUid + "?seasonUid=Personal_Best");
}

Net::HttpRequest@ GetCoreAsync(const string &in endpoint) {
    return GetAsync(audienceCore, NadeoServices::BaseURLCore() + endpoint);
}

Net::HttpRequest@ GetLiveAsync(const string &in endpoint) {
    return GetAsync(audienceLive, NadeoServices::BaseURLLive() + endpoint);
}

string GetMapIdAsync() {
    const string funcName = "GetMapIdAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetCoreAsync("/maps/?mapUidList=" + mapUid);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return "";
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return "";

    if (parsed.Length == 0) {
        warn(funcName + ": parsed is empty");
        return "";
    }

    Json::Value@ map = parsed[0];
    if (!JsonIsObject(map, funcName + ": map"))
        return "";

    if (!map.HasKey("mapId")) {
        warn(funcName + ": map missing key 'mapId'");
        return "";
    }

    const string mapId = string(map["mapId"]);

    trace(funcName + ": success");

    return mapId;
}

void GetPlayerClubInfoAsync() {
    const string funcName = "GetPlayerClubInfoAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/club/player/info");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("hasClubVip")) {
        warn(funcName + ": parsed missing key 'hasClubVip'");
        return;
    }

    hasClubVip = bool(parsed["hasClubVip"]);

    if (!parsed.HasKey("hasPlayerVip")) {
        warn(funcName + ": parsed missing key 'hasPlayerVip'");
        return;
    }

    hasPlayerVip = bool(parsed["hasPlayerVip"]);

    if (!parsed.HasKey("pinnedClub")) {
        warn(funcName + ": parsed missing key 'pinnedClub'");
        return;
    }

    pinnedClub = uint(parsed["pinnedClub"]);

    trace(funcName + ": success");
}

void GetPlayerVIPsAsync() {
    if (!hasPlayerVip)
        return;

    GetVIPsAsync("GetPlayerVIPsAsync", "/api/token/club/player-vip/map/" + mapUid + "?seasonUid=Personal_Best");
}

void GetRecordsAsync() {
    const string funcName = "GetRecordsAsync";
    trace(funcName + ": starting");

    const string mapId = GetMapIdAsync();
    if (mapId.Length == 0) {
        warn(funcName + ": mapId blank");
        return;
    }

    Net::HttpRequest@ req = GetCoreAsync("/mapRecords/?accountIdList=" + string::Join(accountsById.GetKeys(), "%2C") + "&mapIdList=" + mapId);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (records): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return;

    if (parsed.Length == 0) {
        warn(funcName + ": parsed is empty");
        return;
    }

    for (uint i = 0; i < parsed.Length; i++) {
        Json::Value@ record = parsed[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn(funcName + ": record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = record["accountId"];

        if (!record.HasKey("timestamp")) {
            warn(funcName + ": record " + i + " missing key 'timestamp'");
            continue;
        }

        const string timestampIso = string(record["timestamp"]);
        const int64 timestamp = IsoToUnix(timestampIso);

        Account@ account = cast<Account@>(accountsById[accountId]);
        account.timestamp = timestamp;
        // print(account);
    }

    trace(funcName + ": success");
}

void GetSurroundAsync() {
    const string funcName = "GetSurroundAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("tops")) {
        warn(funcName + ": parsed missing key 'tops'");
        return;
    }

    Json::Value@ tops = parsed["tops"];
    if (!JsonIsArray(tops, funcName + ": tops"))
        return;

    if (tops.Length == 0) {
        warn(funcName + ": tops is empty");
        return;
    }

    for (uint i = 0; i < tops.Length; i++) {
        Json::Value@ region = tops[i];
        if (!JsonIsObject(region, funcName + ": region " + i))
            continue;

        if (!region.HasKey("top")) {
            warn(funcName + ": region " + i + " missing key 'top'");
            continue;
        }

        Json::Value@ regionTop = region["top"];
        if (!JsonIsArray(regionTop, funcName + ": regionTop " + i))
            continue;

        for (uint j = 0; j < regionTop.Length; j++) {
            Json::Value@ record = regionTop[j];
            if (!JsonIsObject(record, funcName + ": record " + i + " " + j))
                continue;

            if (!record.HasKey("accountId")) {
                warn(funcName + ": record " + i + " " + j + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(record["accountId"]);

            if (!accountsById.Exists(accountId)) {
                accountsById[accountId] = Account(accountId);
                accountsQueue.InsertLast(accountId);
            }
        }
    }

    trace(funcName + ": success");
}

void GetTopAsync() {
    const string funcName = "GetTopAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + "+ parsed"))
        return;

    if (!parsed.HasKey("tops")) {
        warn(funcName + ": parsed missing key 'tops'");
        return;
    }

    Json::Value@ tops = parsed["tops"];
    if (!JsonIsArray(tops, funcName + ": tops"))
        return;

    if (tops.Length == 0) {
        warn(funcName + ": tops is empty");
        return;
    }

    for (uint i = 0; i < tops.Length; i++) {
        Json::Value@ region = tops[i];
        if (!JsonIsObject(region, funcName + ": region " + i))
            continue;

        if (!region.HasKey("top")) {
            warn(funcName + ": region " + i + " missing key 'top'");
            continue;
        }

        Json::Value@ regionTop = region["top"];
        if (!JsonIsArray(regionTop, funcName + ": regionTop " + i))
            continue;

        for (uint j = 0; j < regionTop.Length; j++) {
            Json::Value@ record = regionTop[j];
            if (!JsonIsObject(record, funcName + ": record " + i + " " + j))
                continue;

            if (!record.HasKey("accountId")) {
                warn(funcName + ": record " + i + " " + j + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(record["accountId"]);

            if (!accountsById.Exists(accountId)) {
                accountsById[accountId] = Account(accountId);
                accountsQueue.InsertLast(accountId);
            }
        }
    }

    trace(funcName + ": success");
}

void GetVIPsAsync(const string &in funcName, const string &in endpoint) {
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("accountIdList")) {
        warn(funcName + ": parsed missing key 'accountIdList'");
        return;
    }

    Json::Value@ accounts = parsed["accountIdList"];
    if (!JsonIsArray(accounts, funcName + ": accounts"))
        return;

    if (accounts.Length == 0) {
        warn(funcName + ": accounts is empty");
        return;
    }

    for (uint i = 0; i < accounts.Length; i++) {
        const string accountId = string(accounts[i]);

        if (!accountsById.Exists(accountId)) {
            accountsById[accountId] = Account(accountId);
            accountsQueue.InsertLast(accountId);
        }
    }

    trace(funcName + ": success");
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

void Reset() {
    accountsById.DeleteAll();
    accountsByName.DeleteAll();
    hasClubVip   = false;
    hasPlayerVip = false;
    mapUid       = "";
    pinnedClub   = 0;
}

string UnixToIso(uint timestamp) {
    return Time::FormatString("%Y-%m-%d \\$AAA@ \\$G%H:%M:%S \\$AAA(%a)\\$G", timestamp);
}
