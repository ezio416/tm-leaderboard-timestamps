// c 2024-06-21
// m 2024-07-10

dictionary@       accountsById   = dictionary();
dictionary@       accountsByName = dictionary();
string[]          accountsQueue;
const string      audienceCore   = "NadeoServices";
const string      audienceLive   = "NadeoLiveServices";
bool              canViewRecords = false;
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
    canViewRecords = Permissions::ViewRecords();
    if (!canViewRecords)
        return;

    NadeoServices::AddAudience(audienceCore);
    NadeoServices::AddAudience(audienceLive);

    bool inMap             = false;
    bool isDisplayRecords  = false;
    uint pb                = 0;
    bool wasDisplayRecords = false;
    bool wasInMap          = false;

    while (true) {
        yield();

        if (!S_Enabled) {
            wasInMap = false;
            continue;
        }

        menuOpen = false;

        inMap = InMap();

        bool enteredMap = false;

        if (wasInMap != inMap) {
            wasInMap = inMap;

            if (inMap) {
                enteredMap = true;
                trace("entered map");
                startnew(GetTimestampsAsync);
            }
        }

        if (!inMap) {
            Reset();
            continue;
        }

        bool gotNewPb = false;

        const uint newPb = GetPersonalBestAsync();
        if (newPb > 0 && pb != newPb) {
            pb = newPb;
            gotNewPb = true;
            trace("new PB found");
            startnew(GetTimestampsAsync);
        }

        isDisplayRecords = AlwaysDisplayRecords();
        if (wasDisplayRecords != isDisplayRecords) {
            wasDisplayRecords = isDisplayRecords;

            if (isDisplayRecords && !enteredMap && !gotNewPb) {
                trace("leaderboard refreshed");
                startnew(GetTimestampsAsync);
            }
        }

        if (accountsQueue.Length > 0) {
            const string accountId = accountsQueue[0];
            const string name = NadeoServices::GetDisplayNameAsync(accountId);
            // print("accountId " + accountId + " has name " + name);
            Account@ account = cast<Account@>(accountsById[accountId]);
            if (account !is null) {
                account.name = name;
                accountsByName[name] = @account;
            }
            accountsQueue.RemoveAt(0);
        }
    }
}

void Render() {
    if (false
        || !S_Enabled
        || (S_HideWithOP && !UI::IsOverlayShown())
        || !canViewRecords
        || menuOpen
    )
        return;

    const string name = HoveredName();

    if (false
        || name.Length == 0
        || name.StartsWith("\u0092")  // medals
    )
        return;

    UI::BeginTooltip();
        if (true
            && !S_Timestamp
            && !S_Recency
        )
            UI::Text("\\$FA0Enable an option in the settings!");
        else {
            const string loadingText = "\\$AAAloading...";

            if (accountsByName.Exists(name)) {
                Account@ account = cast<Account@>(accountsByName[name]);
                if (account.timestamp > 0) {
                    if (S_Timestamp)
                        UI::Text(UnixToIso(account.timestamp));
                    if (S_Recency)
                        UI::Text(FormatSeconds(Time::Stamp - account.timestamp) + " ago");
                } else
                    UI::Text(loadingText);
            } else
                UI::Text(loadingText);
        }
    UI::EndTooltip();
}

void RenderMenu() {
    menuOpen = true;

    if (canViewRecords && UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void GetTimestampsAsync() {
    while (getting)
        yield();

    const string funcName = "GetTimestampsAsync";
    trace(funcName + ": starting");
    getting = true;

    Reset();

    if (!InMap()) {
        getting = false;
        return;
    }

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceLive))
        yield();

    GetRegionsTopAsync();
    GetRegionsSurroundAsync();
    GetPlayerClubInfoAsync();
    GetClubSurroundAsync();
    GetClubTopAsync();
    GetClubVIPsAsync();
    GetPlayerVIPsAsync();

    while (!NadeoServices::IsAuthenticated(audienceCore))
        yield();

    GetRecordsAsync();

    trace(funcName + ": success");
    getting = false;
}

string HoveredName() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null || CMAP.UILayers.Length == 0)
        return "";

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
        return "";

    CGameManialinkQuad@ Focused = cast<CGameManialinkQuad@>(RecordsTable.FocusedControl);
    if (Focused is null)
        return "";

    CGameManialinkFrame@ Parent = cast<CGameManialinkFrame@>(Focused.Parent);
    if (Parent is null)
        return "";

    CGameManialinkFrame@ Frame1;
    for (uint i = 0; i < Parent.Controls.Length; i++) {
        CGameManialinkFrame@ Frame = cast<CGameManialinkFrame@>(Parent.Controls[i]);
        if (Frame !is null) {
            @Frame1 = Frame;
            break;
        }
    }
    if (Frame1 is null || Frame1.Controls.Length == 0)
        return "";

    CGameManialinkFrame@ Frame2 = cast<CGameManialinkFrame@>(Frame1.Controls[0]);
    if (Frame2 is null || Frame2.Controls.Length == 0)
        return "";

    CGameManialinkFrame@ Frame3 = cast<CGameManialinkFrame@>(Frame2.Controls[0]);
    if (Frame3 is null || Frame3.Controls.Length == 0)
        return "";

    CGameManialinkLabel@ TheLabel;
    for (uint i = 0; i < Frame3.Controls.Length; i++) {
        CGameManialinkLabel@ Label = cast<CGameManialinkLabel@>(Frame3.Controls[i]);
        if (Label !is null) {
            @TheLabel = Label;
            break;
        }
    }
    if (TheLabel is null)
        return "";

    return TheLabel.Value;
}

void Reset() {
    accountsById.DeleteAll();
    accountsByName.DeleteAll();
    hasClubVip   = false;
    hasPlayerVip = false;
    mapUid       = "";
    pinnedClub   = 0;
}
