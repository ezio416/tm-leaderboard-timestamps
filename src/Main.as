// c 2024-06-21
// m 2025-03-19

dictionary@  accountsById    = dictionary();
dictionary@  accountsByName  = dictionary();
string[]     accountsQueue;
const string audienceCore    = "NadeoServices";
const string audienceLive    = "NadeoLiveServices";
bool         canViewRecords  = false;
bool         getting         = false;
bool         hasClubVip      = false;
bool         hasPlayerVip    = false;
const string legacyLoadText  = "\\$AAAloading...";
string       mapUid;
bool         menuOpen        = false;
bool         newLocalPb      = false;
uint         pinnedClub      = 0;
int          raceRecordIndex = -1;
const float  scale           = UI::GetScale();
const float  stdRatio        = 16.0f / 9.0f;
const string title           = "\\$0AF" + Icons::ListOl + "\\$G Leaderboard Timestamps";
const uint64 waitTime        = 500;

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

    ChangeFont();

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    if (!S_InitV2) {
        switch(int(Draw::GetHeight())) {
            case 720:
                S_FontSize         = 6;
                S_TimestampOffsetX = 96.0f;
                S_TimestampOffsetY = -6.0f;
                S_RecencyOffsetX   = 96.0f;
                S_RecencyOffsetY   = 9.0f;
                break;

            case 1080:
                S_FontSize         = 7;
                S_TimestampOffsetX = 144.0f;
                S_TimestampOffsetY = -9.0f;
                S_RecencyOffsetX   = 144.0f;
                S_RecencyOffsetY   = 12.0f;
                break;

            case 1440:
                S_FontSize         = 10;
                S_TimestampOffsetX = 192.0f;
                S_TimestampOffsetY = -12.0f;
                S_RecencyOffsetX   = 192.0f;
                S_RecencyOffsetY   = 17.0f;
                break;

            case 2160:
                S_FontSize         = 14;
                S_TimestampOffsetX = 288.0f;
                S_TimestampOffsetY = -19.0f;
                S_RecencyOffsetX   = 288.0f;
                S_RecencyOffsetY   = 24.0f;
                break;

            default:;
        }

        S_InitV2 = true;
    }

    while (true) {
        yield();

        if (!S_Enabled) {
            wasInMap = InMap();
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
            const uint oldPb = pb;
            pb = newPb;
            gotNewPb = true;
            trace("new PB found");

            if (false
                || pb <= App.RootMap.TMObjective_AuthorTime
                || (pb <= App.RootMap.TMObjective_GoldTime && oldPb > App.RootMap.TMObjective_GoldTime)
                || (pb <= App.RootMap.TMObjective_SilverTime && oldPb > App.RootMap.TMObjective_SilverTime)
                || (pb <= App.RootMap.TMObjective_BronzeTime && oldPb > App.RootMap.TMObjective_BronzeTime)
            ) {
                newLocalPb = false;
                startnew(GetTimestampsAsync);
            } else
                newLocalPb = true;
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

void OnSettingsChanged() {
    if (S_FontSize < 6)
        S_FontSize = 6;
    if (S_FontSize > 72)
        S_FontSize = 72;

    ChangeFont();
}

void Render() {
    if (false
        || !S_Enabled
        || !UI::IsGameUIVisible()
        || (S_HideWithOP && !UI::IsOverlayShown())
        || !canViewRecords
        || !InMap()
    )
        return;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    if (App.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed)
        return;

    const string mapType = string(App.RootMap.MapType);
    if (false
        || mapType.Contains("TM_Platform")
        || mapType.Contains("TM_Royal")
        // || mapType.Contains("TM_Stunt")
    )
        return;

    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null || CMAP.UILayers.Length == 0)
        return;

    CGameManialinkPage@ RecordsTable;

    if (raceRecordIndex > -1 && CMAP.UILayers.Length > uint(raceRecordIndex)) {
        CGameUILayer@ Layer = CMAP.UILayers[raceRecordIndex];

        if (true
            && Layer !is null
            && Layer.Type == CGameUILayer::EUILayerType::Normal
            && Layer.ManialinkPageUtf8.Length > 0
        ) {
            const int start = Layer.ManialinkPageUtf8.IndexOf("<");
            const int end = Layer.ManialinkPageUtf8.IndexOf(">");
            if (start > -1 && end > -1) {
                if (Layer.ManialinkPageUtf8.SubStr(start, end).Contains("_Race_Record"))
                    @RecordsTable = Layer.LocalPage;
            }
        }
    }

    if (RecordsTable is null) {
        for (uint i = 0; i < CMAP.UILayers.Length; i++) {
            CGameUILayer@ Layer = CMAP.UILayers[i];

            if (false
                || Layer is null
                || Layer.Type != CGameUILayer::EUILayerType::Normal
                || Layer.ManialinkPageUtf8.Length == 0
            )
                continue;

            const int start = Layer.ManialinkPageUtf8.IndexOf("<");
            const int end = Layer.ManialinkPageUtf8.IndexOf(">");
            if (start == -1 || end == -1)
                continue;

            if (Layer.ManialinkPageUtf8.SubStr(start, end).Contains("_Race_Record")) {
                @RecordsTable = Layer.LocalPage;
                raceRecordIndex = i;
                break;
            }
        }
    }

    if (RecordsTable is null)
        return;

    if (S_Legacy)
        RenderLegacy(RecordsTable);
    else
        RenderAll(RecordsTable);
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

    const string mapType = string(App.RootMap.MapType);
    if (false
        || mapType.Contains("TM_Platform")
        || mapType.Contains("TM_Royal")
        // || mapType.Contains("TM_Stunt")
    ) {
        warn(funcName + ": bad map type (" + mapType + ")");
        getting = false;
        return;
    }

    mapUid = App.RootMap.EdChallengeId;

    while (!NadeoServices::IsAuthenticated(audienceLive))
        yield();

    GetRegionsTopAsync();
    if (!InMap()) {
        getting = false;
        return;
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

    while (!NadeoServices::IsAuthenticated(audienceCore))
        yield();

    GetRecordsAsync();

    trace(funcName + ": success");
    getting = false;
}

void RenderAll(CGameManialinkPage@ RecordsTable) {
    if (!S_Timestamp && !S_Recency)
        return;

    CGameManialinkFrame@ Container = cast<CGameManialinkFrame@>(RecordsTable.GetFirstChild("frame-rankings-container"));
    if (Container is null)
        return;

    // bool scroll = false;

    CGameManialinkFrame@ RankingFrame = cast<CGameManialinkFrame@>(Container.GetFirstChild("frame-ranking"));
    if (RankingFrame is null || !RankingFrame.Visible) {
        @RankingFrame = cast<CGameManialinkFrame@>(Container.GetFirstChild("scroll-ranking"));  // VIPs
        // scroll = true;
    }
    if (RankingFrame is null || !RankingFrame.Visible)
        return;

    // if (scroll && RankingFrame.ScrollMax.y > 0.0f) {
    //     UI::Text("count: " + (int(RankingFrame.ScrollMax.y / 6.0f) + 8));
    //     UI::Text(
    //         "scroll: "
    //         + Text::Format("%.3f", RankingFrame.ScrollOffset.y)
    //         + "/"
    //         + Text::Format("%.3f", RankingFrame.ScrollMax.y)
    //         + " ("
    //         + Text::Format("%.1f", 100.0f * RankingFrame.ScrollOffset.y / RankingFrame.ScrollMax.y)
    //         + " %)"
    //     );
    //     UI::Separator();
    // }

    nvg::FontFace(font);
    nvg::FillColor(S_FontColor);
    nvg::FontSize(S_FontSize);

    for (uint i = 0; i < RankingFrame.Controls.Length && i < 9; i++)
        RenderRanking(RankingFrame.Controls[i]);
}

void RenderLegacy(CGameManialinkPage@ RecordsTable) {
    if (menuOpen)
        return;

    CGameManialinkQuad@ Focused = cast<CGameManialinkQuad@>(RecordsTable.FocusedControl);
    if (Focused is null || !Focused.Visible || Focused.Parent is null)
        return;

    CGameManialinkLabel@ NameLabel = cast<CGameManialinkLabel@>(
        Focused.Parent.GetFirstChild("cmgame-player-name_label-name")
    );
    if (NameLabel is null || NameLabel.Value.Length == 0)
        return;

    const string name = string(NameLabel.Value);
    if (false
        || name.Length == 0
        || name.StartsWith("\u0092")  // medals
        || (newLocalPb && name == string(GetApp().LocalPlayerInfo.Name))
    )
        return;

    UI::BeginTooltip();

    if (!S_Timestamp && !S_Recency)
        UI::Text("\\$FA0Enable an option in the settings!");

    else {
        if (!accountsByName.Exists(name))
            UI::Text(legacyLoadText);

        else {
            Account@ account = cast<Account@>(accountsByName[name]);
            if (account.timestamp < 1)
                UI::Text(legacyLoadText);

            else {
                if (S_Timestamp)
                    UI::Text(UnixToIso(account.timestamp));

                if (S_Recency)
                    UI::Text(FormatSeconds(Time::Stamp - account.timestamp) + " ago");
            }
        }
    }

    UI::EndTooltip();
}

void RenderRanking(CGameManialinkControl@ control) {
    CGameManialinkFrame@ frame = cast<CGameManialinkFrame@>(control);
    if (frame is null || !frame.Visible)
        return;

    CGameManialinkLabel@ NameLabel = cast<CGameManialinkLabel@>(
        frame.GetFirstChild("cmgame-player-name_label-name")
    );
    if (NameLabel is null || NameLabel.Value.Length == 0)
        return;

    Account@ account;
    const string name = string(NameLabel.Value);
    if (newLocalPb && name == string(GetApp().LocalPlayerInfo.Name))
        return;
    if (accountsByName.Exists(name))
        @account = cast<Account@>(accountsByName[name]);
    if (account is null || account.timestamp < 1)
        return;

    const float w       = Math::Max(1, Draw::GetWidth());
    const float h       = Math::Max(1, Draw::GetHeight());
    const vec2  center  = vec2(w * 0.5f, h * 0.5f);
    const float unit    = (w / h < stdRatio) ? w / 320.0f : h / 180.0f;
    const vec2  scale   = vec2(unit, -unit);
    const vec2  basePos = center + scale * NameLabel.AbsolutePosition_V3;

    if (S_Timestamp) {
        nvg::Text(
            basePos + vec2(S_TimestampOffsetX, S_TimestampOffsetY),
            TimeFormatString(
                Text::StripFormatCodes(S_TimestampFormat),
                account.timestamp
            )
        );
    }

    if (S_Recency) {
        nvg::Text(
            basePos + vec2(S_RecencyOffsetX, S_RecencyOffsetY),
            FormatSeconds(Time::Stamp - account.timestamp) + " ago"
        );
    }
}

void Reset() {
    accountsById.DeleteAll();
    accountsByName.DeleteAll();
    hasClubVip      = false;
    hasPlayerVip    = false;
    mapUid          = "";
    newLocalPb      = false;
    pinnedClub      = 0;
    raceRecordIndex = -1;
}
