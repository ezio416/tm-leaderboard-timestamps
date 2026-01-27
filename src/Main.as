dictionary   accountsById;
dictionary   accountsByName;
string[]     accountsQueue;
const string audienceCore            = "NadeoServices";
const string audienceLive            = "NadeoLiveServices";
bool         cancel                  = false;
const bool   canViewRecords          = Permissions::ViewRecords();
bool         getting                 = false;
bool         hasClubVip              = false;
bool         hasPlayerVip            = false;
string       lastUid;
const string legacyLoadText          = "\\$AAAloading...";
dictionary   mapIds;
string       mapUid;
dictionary   medalGhosts;
bool         menuOpen                = false;
bool         newLocalPb              = false;
bool         onlySurround            = false;
uint         pb                      = 0;
uint         pinnedClub              = 0;
string       playerId;
string       playerName;
int          raceRecordIndex         = -1;
const float  stdRatio                = 16.0f / 9.0f;
uint         surroundScore           = 0;
bool         timeFormatValid         = false;
const string title                   = "\\$0AF" + Icons::ListOl + "\\$G Leaderboard Timestamps";
uint         valueOverlayConfirmQuit = 0;
uint         valueOverlaySettings    = 0;
const uint64 waitTime                = 500;

void Main() {
    if (!canViewRecords)
        return;

    NadeoServices::AddAudience(audienceCore);
    NadeoServices::AddAudience(audienceLive);

    bool inMap             = false;
    bool isDisplayRecords  = false;
    bool wasDisplayRecords = false;
    bool wasInMap          = false;

    OnSettingsChanged();

    auto App = cast<CTrackMania>(GetApp());

    playerId = App.LocalPlayerInfo.WebServicesUserId;
    playerName = App.LocalPlayerInfo.Name;

    if (!S_InitV2) {
        switch(int(Display::GetHeight())) {
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

        if (inMap) {
            auto Map = GetApp().RootMap;
            if (Map !is null) {
                mapUid = Map.EdChallengeId;
                if (lastUid != mapUid) {
                    lastUid = mapUid;
                    Reset();
                    continue;
                    // enteredMap = true;
                }
            }
        }

        if (wasInMap != inMap) {
            wasInMap = inMap;

            if (inMap) {
                enteredMap = true;
                trace("entered map");
                startnew(GetTimestampsAsync);

                pb = GetPersonalBest();
                trace("existing pb: " + Time::Format(pb));

                continue;
            }
        }

        if (!inMap) {
            Reset();
            accountsById.DeleteAll();
            accountsByName.DeleteAll();
            medalGhosts.DeleteAll();
            surroundScore = 0;
            continue;
        }

        bool gotNewPb = false;

        const uint newPb = GetPersonalBestAsync();
        if (true
            and newPb > 0
            and pb != newPb
        ) {
            surroundScore = newPb;

            const uint oldPb = pb != 0 ? pb : uint(-1);
            pb = newPb;
            gotNewPb = true;

            trace("pb: " + Time::Format(pb) + ", oldPb: " + Time::Format(oldPb) + ", newPb: " + Time::Format(newPb));

            if (oldPb == uint(-1)) {
                trace("new pb found (" + Time::Format(newPb) + ")");
            } else {
                trace("new pb found (was " + Time::Format(oldPb)
                    + ", now " + Time::Format(newPb)
                    + ", diff of " + Time::Format(oldPb - newPb)
                + ")");
            }

            // if (accountsById.Exists(playerId)) {
            //     auto me = cast<Account>(accountsById[playerId]);
            //     if (me.time != pb)
            //         warn("local pb (" + Time::Format(pb) + ") does not match api (" + Time::Format(me.time) + ")");
            //     else
            //         print("fine and dandy");
            // } else
            //     warn("account not found: " + playerId);

            newLocalPb = !(false  // negating the logic of an uploaded record like this is simpler
                or pb <= App.RootMap.TMObjective_AuthorTime
                or (true
                    and oldPb > App.RootMap.TMObjective_GoldTime
                    and pb <= App.RootMap.TMObjective_GoldTime
                )
                or (true
                    and oldPb > App.RootMap.TMObjective_SilverTime
                    and pb <= App.RootMap.TMObjective_SilverTime
                )
                or (true
                    and oldPb > App.RootMap.TMObjective_BronzeTime
                    and pb <= App.RootMap.TMObjective_BronzeTime
                )
            );

            if (newLocalPb) {
                warn("new local pb driven that won't upload until the player exits the map");
                onlySurround = true;

                if (S_Warning) {
                    UI::ShowNotification(
                        title,
                        "New PB of " + Time::Format(pb) + " won't upload until you exit the map. Try getting another medal!",
                        10000
                    );
                }
            }

            CancelAsync();
            GetTimestampsAsync();
        }

        isDisplayRecords = AlwaysDisplayRecords();
        if (wasDisplayRecords != isDisplayRecords) {
            wasDisplayRecords = isDisplayRecords;

            if (true
                and isDisplayRecords
                and !enteredMap
                and !gotNewPb
            ) {
                trace("leaderboard refreshed");
                CancelAsync();
                startnew(GetTimestampsAsync);
            }
        }

        if (accountsQueue.Length > 0) {
            const string accountId = accountsQueue[0];
            const string name = NadeoServices::GetDisplayNameAsync(accountId);
            auto account = cast<Account>(accountsById[accountId]);
            if (account !is null) {
                account.name = name;
                accountsByName[name] = @account;
            }
            accountsQueue.RemoveAt(0);
        }
    }
}

void OnSettingsChanged() {
    S_FontSize = Math::Clamp(S_FontSize, 6, 72);

    timeFormatValid = VerifyTimeFormat();

    ChangeFont();
}

void Render() {
    if (false
        or !S_Enabled
        or !UI::IsGameUIVisible()
        or (true
            and S_HideWithOP
            and !UI::IsOverlayShown()
        )
        or !canViewRecords
        or !InMap()
    ) {
        return;
    }

    auto App = cast<CTrackMania>(GetApp());

    if (App.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed) {
        return;
    }

    const string mapType = string(App.RootMap.MapType);
    if (false
        or mapType.Contains("TM_Platform")
        or mapType.Contains("TM_Royal")
    ) {
        return;
    }

    auto Network = cast<CTrackManiaNetwork>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (false
        or CMAP is null
        or CMAP.UILayers.Length == 0
    ) {
        return;
    }

    for (int i = App.Viewport.Overlays.Length - 1; i >= 0; i--) {
        CHmsZoneOverlay@ Overlay = App.Viewport.Overlays[i];
        if (false
            or Overlay is null
            or Overlay.m_CorpusVisibles.Length == 0
            or Overlay.m_CorpusVisibles[0] is null
            or Overlay.m_CorpusVisibles[0].Item is null
            or Overlay.m_CorpusVisibles[0].Item.SceneMobil is null
        ) {
            continue;
        }

        if (false
            or (true
                and valueOverlayConfirmQuit > 0
                and valueOverlayConfirmQuit == Overlay.m_CorpusVisibles[0].Item.SceneMobil.Id.Value
            )
            or (true
                and valueOverlaySettings > 0
                and valueOverlaySettings == Overlay.m_CorpusVisibles[0].Item.SceneMobil.Id.Value
                and Overlay.m_CorpusVisibles.Length > 300
                and Overlay.m_CorpusVisibles[0].Item.IsVisible
            )
        ) {
            return;
        }

        if (Overlay.m_CorpusVisibles[0].Item.SceneMobil.IdName == "FrameConfirmQuit") {
            valueOverlayConfirmQuit = Overlay.m_CorpusVisibles[0].Item.SceneMobil.Id.Value;
            return;
        }

        if (Overlay.m_CorpusVisibles[0].Item.SceneMobil.IdName == "InterfaceRoot") {
            auto Mobil = cast<CControlFrameStyled>(Overlay.m_CorpusVisibles[0].Item.SceneMobil);
            if (true
                and Mobil !is null
                and Mobil.Childs.Length > 0
                and Mobil.Childs[0] !is null
                and Mobil.Childs[0].IdName == "FrameManialinkPageContainer"
            ) {
                valueOverlaySettings = Mobil.Id.Value;
            }
        }
    }

    CGameManialinkPage@ RecordsTable;

    if (true
        and raceRecordIndex > -1
        and CMAP.UILayers.Length > uint(raceRecordIndex)
    ) {
        CGameUILayer@ Layer = CMAP.UILayers[raceRecordIndex];

        if (true
            and Layer !is null
            and Layer.Type == CGameUILayer::EUILayerType::Normal
            and Layer.ManialinkPageUtf8.Length > 0
        ) {
            const int start = Layer.ManialinkPageUtf8.IndexOf("<");
            const int end = Layer.ManialinkPageUtf8.IndexOf(">");
            if (true
                and start > -1
                and end > -1
            ) {
                if (Layer.ManialinkPageUtf8.SubStr(start, end).Contains("_Race_Record"))
                    @RecordsTable = Layer.LocalPage;
            }
        }
    }

    if (RecordsTable is null) {
        for (uint i = 0; i < CMAP.UILayers.Length; i++) {
            CGameUILayer@ Layer = CMAP.UILayers[i];

            if (false
                or Layer is null
                or Layer.Type != CGameUILayer::EUILayerType::Normal
                or Layer.ManialinkPageUtf8.Length == 0
            ) {
                continue;
            }

            const int start = Layer.ManialinkPageUtf8.IndexOf("<");
            const int end = Layer.ManialinkPageUtf8.IndexOf(">");
            if (false
                or start == -1
                or end == -1
            ) {
                continue;
            }

            if (Layer.ManialinkPageUtf8.SubStr(start, end).Contains("_Race_Record")) {
                @RecordsTable = Layer.LocalPage;
                raceRecordIndex = i;
                break;
            }
        }
    }

    if (RecordsTable is null) {
        return;
    }

    if (S_Legacy) {
        RenderLegacy(RecordsTable);
    } else {
        RenderAll(RecordsTable);
    }
}

void RenderMenu() {
    menuOpen = true;

    if (true
        and canViewRecords
        and UI::MenuItem(title, "", S_Enabled)
    ) {
        S_Enabled = !S_Enabled;
    }
}
