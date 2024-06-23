// c 2024-06-21
// m 2024-06-23

dictionary@       accountsById   = dictionary();
dictionary@       accountsByName = dictionary();
string[]          accountsQueue;
const string      audienceCore   = "NadeoServices";
const string      audienceLive   = "NadeoLiveServices";
bool              menuOpen       = false;
const float       scale          = UI::GetScale();
SQLite::Database@ timeDB         = SQLite::Database(":memory:");
const string      title          = "\\$FFF" + Icons::Arrows + "\\$G Leaderboard Timestamps";

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

    if (UI::Begin(title, S_Enabled, UI::WindowFlags::None)) {
        if (UI::Button("get records"))
            startnew(GetRecordsAsync);

        UI::Text("queue: " + accountsQueue.Length);

        string[]@ names = accountsByName.GetKeys();

        for (uint i = 0; i < names.Length; i++) {
            const string name = names[i];
            Account@ account = cast<Account@>(accountsByName[name]);
            UI::Text(tostring(account));
        }
    }
    UI::End();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null || CMAP.UILayers.Length == 0)
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
        UI::Text(name);

        if (accountsByName.Exists(name)) {
            Account@ account = cast<Account@>(accountsByName[name]);
            UI::Text(tostring(account));
        } else
            UI::Text("...");
    }
    UI::End();
}

void GetRecordsAsync() {
    accountsById.DeleteAll();
    accountsByName.DeleteAll();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    if (
        App.RootMap is null
        || App.CurrentPlayground is null
        || App.Editor !is null
    )
        return;

    const string mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceCore))
        yield();

    while (!NadeoServices::IsAuthenticated(audienceLive))
        yield();

    sleep(500);
    print("getting tops");
    Net::HttpRequest@ req = NadeoServices::Get(
        audienceLive,
        NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top"
    );
    req.Start();
    while (!req.Finished())
        yield();

    int code = req.ResponseCode();
    string msg = req.String();
    if (code != 200) {
        warn("req (top): code: " + code + " | error: " + req.Error() + " | resp: " + msg);
        return;
    }

    Json::Value@ top = Json::Parse(msg);
    const Json::Type topType = top.GetType();
    if (topType != Json::Type::Object) {
        warn("top is a(n) " + tostring(topType) + ", not an Object");
        return;
    }

    if (!top.HasKey("tops")) {
        warn("tops missing key 'tops'");
        return;
    }

    Json::Value@ tops = top["tops"];
    const Json::Type topsType = tops.GetType();
    if (topsType != Json::Type::Array) {
        warn("tops is a(n) " + tostring(topType) + ", not an Array");
        return;
    }

    if (tops.Length == 0) {
        warn("tops is empty");
        return;
    }

    for (uint i = 0; i < tops.Length; i++) {
        Json::Value@ region = tops[i];
        const Json::Type regionType = region.GetType();
        if (regionType != Json::Type::Object) {
            warn("region " + i + " is a(n) " + tostring(regionType) + ", not an Object");
            continue;
        }

        if (!region.HasKey("top")) {
            warn("region " + i + " missing key 'top'");
            continue;
        }

        Json::Value@ regionTop = region["top"];
        const Json::Type regionTopType = regionTop.GetType();
        if (regionTopType != Json::Type::Array) {
            warn("regionTop " + i + " is a(n) " + tostring(topType) + ", not an Array");
            continue;
        }

        for (uint j = 0; j < regionTop.Length; j++) {
            Json::Value@ regionTopRecord = regionTop[j];
            const Json::Type regionTopRecordType = regionTopRecord.GetType();
            if (regionTopRecordType != Json::Type::Object) {
                warn("regionTopRecord " + i + " " + j + "is a(n) " + tostring(regionTopRecordType) + ", not an Object");
                continue;
            }

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

    sleep(500);
    print("getting map info");
    @req = NadeoServices::Get(
        audienceCore,
        NadeoServices::BaseURLCore() + "/maps/?mapUidList=" + mapUid
    );
    req.Start();
    while (!req.Finished())
        yield();

    code = req.ResponseCode();
    msg = req.String();
    if (code != 200) {
        warn("req (map info): code: " + code + " | error: " + req.Error() + " | resp: " + msg);
        return;
    }

    Json::Value@ mapInfo = Json::Parse(msg);
    const Json::Type mapInfoType = mapInfo.GetType();
    if (mapInfoType != Json::Type::Array) {
        warn("mapInfo is a(n) " + tostring(mapInfoType) + ", not an Array");
        return;
    }

    if (mapInfo.Length == 0) {
        warn("mapInfo is empty");
        return;
    }

    Json::Value@ map = mapInfo[0];
    const Json::Type mapType = map.GetType();
    if (mapType != Json::Type::Object) {
        warn("mapInfo is a(n) " + tostring(mapType) + ", not an Object");
        return;
    }

    if (!map.HasKey("mapId")) {
        warn("map missing key 'mapId'");
        return;
    }

    const string mapId = string(map["mapId"]);

    sleep(500);
    print("getting records");
    @req = NadeoServices::Get(
        audienceCore,
        NadeoServices::BaseURLCore() + "/mapRecords/?accountIdList=" + string::Join(accountsById.GetKeys(), "%2C") + "&mapIdList=" + mapId
    );
    req.Start();
    while (!req.Finished())
        yield();

    code = req.ResponseCode();
    msg = req.String();
    if (code != 200) {
        warn("req (records): code: " + code + " | error: " + req.Error() + " | resp: " + msg);
        return;
    }

    Json::Value@ records = Json::Parse(msg);
    const Json::Type recordsType = records.GetType();
    if (recordsType != Json::Type::Array) {
        warn("records is a(n) " + tostring(recordsType) + ", not an Array");
        return;
    }

    if (records.Length == 0) {
        warn("records is empty");
        return;
    }

    for (uint i = 0; i < records.Length; i++) {
        Json::Value@ record = records[i];
        const Json::Type recordType = record.GetType();
        if (recordType != Json::Type::Object) {
            warn("record " + i + " is a(n) " + tostring(recordType) + ", not an Object");
            continue;
        }

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
        print(account);
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
