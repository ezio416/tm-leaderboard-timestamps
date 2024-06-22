// c 2024-06-21
// m 2024-06-21

const float  scale = UI::GetScale();
const string title = "\\$FFF" + Icons::Arrows + "\\$G Leaderboard Timestamps";

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

void Main() {
}

void RenderMenu() {
    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Render() {
    if (
        !S_Enabled
        || (S_HideWithGame && !UI::IsGameUIVisible())
        || (S_HideWithOP && !UI::IsOverlayShown())
    )
        return;

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

    CGameManialinkQuad@ Focused = cast<CGameManialinkQuad@>(RecordsTable.FocusedControl);  // #118301
    if (Focused !is null) {
        CGameManialinkFrame@ Parent = cast<CGameManialinkFrame@>(Focused.Parent);  // #118130
        if (Parent !is null) {
            CGameManialinkFrame@ ParentFrame;  // #118307
            for (uint i = 0; i < Parent.Controls.Length; i++) {
                CGameManialinkFrame@ Frame = cast<CGameManialinkFrame@>(Parent.Controls[i]);
                if (Frame !is null) {
                    @ParentFrame = Frame;
                    break;
                }
            }
            if (ParentFrame !is null && ParentFrame.Controls.Length > 0) {
                CGameManialinkFrame@ Frame2 = cast<CGameManialinkFrame@>(ParentFrame.Controls[0]);  // #118314
                if (Frame2 !is null && Frame2.Controls.Length > 0) {
                    CGameManialinkFrame@ Frame3 = cast<CGameManialinkFrame@>(Frame2.Controls[0]);  // #118315
                    if (Frame3 !is null && Frame3.Controls.Length > 0) {
                        CGameManialinkLabel@ TheLabel;
                        for (uint i = 0; i < Frame3.Controls.Length; i++) {
                            CGameManialinkLabel@ Label = cast<CGameManialinkLabel@>(Frame3.Controls[i]);
                            if (Label !is null) {
                                @TheLabel = Label;
                                break;
                            }
                        }
                        if (TheLabel !is null) {
                            const string name = TheLabel.Value;
                            const vec2 mousePos = UI::GetMousePos();
                            UI::SetNextWindowPos(int(mousePos.x / scale) + 5, int(mousePos.y / scale) + 5, UI::Cond::Always);
                            if (UI::Begin(title, S_Enabled, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoTitleBar)) {
                                UI::Text(name);
                            }
                            UI::End();
                        }
                    }
                }
            }
        }
    }
}

void HoverTooltip(const string &in msg) {
    if (!UI::IsItemHovered())
        return;

    UI::BeginTooltip();
        UI::Text(msg);
    UI::EndTooltip();
}

bool IsSafeToCheckUI() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    return (
        App.RootMap !is null
        && App.CurrentPlayground !is null
        && App.Editor is null
        && IsUIPopulated()
    );
}

uint lastNbUilayers = 0;
bool IsUIPopulated() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;
    CSmArenaClient@ Playground = cast<CSmArenaClient@>(App.CurrentPlayground);

    if (CMAP is null || Playground is null || Playground.UIConfigs.Length == 0 || CMAP.UI is null)
        return false;

    if (!UISequenceGood(CMAP.UI.UISequence))
        return false;

    uint nbUiLayers = CMAP.UILayers.Length;

    // if the number of UI layers decreases it's probably due to a recovery restart, so we don't want to act on old references
    if (nbUiLayers <= 2 || nbUiLayers < lastNbUilayers)
        return false;

    lastNbUilayers = nbUiLayers;

    return true;
}

bool UISequenceGood(CGamePlaygroundUIConfig::EUISequence seq) {
    return
        seq == CGamePlaygroundUIConfig::EUISequence::Playing
        || seq == CGamePlaygroundUIConfig::EUISequence::Finish
        || seq == CGamePlaygroundUIConfig::EUISequence::EndRound
        || seq == CGamePlaygroundUIConfig::EUISequence::UIInteraction;
}

bool ScoreTableVisible() {
    // frame-scorestable-layer is the frame that shows scoreboard
    // but there's a ui layer with type ScoresTable that is called UIModule_Race_ScoresTable_Visibility
    // so probs best to check that (no string operations).

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;

    if (CMAP is null)
        return false;

    uint nbLayersToCheck = uint(Math::Min(8, CMAP.UILayers.Length));

    for (uint i = 2; i < nbLayersToCheck; i++) {
        CGameUILayer@ layer = CMAP.UILayers[i];
        if (layer !is null && layer.Type == CGameUILayer::EUILayerType::ScoresTable)
            return layer.LocalPage !is null && layer.LocalPage.MainFrame !is null && layer.LocalPage.MainFrame.Visible;
    }

    return false;
}
