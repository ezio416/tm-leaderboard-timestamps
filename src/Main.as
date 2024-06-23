// c 2024-06-21
// m 2024-06-22

bool         menuOpen = false;
const float  scale    = UI::GetScale();
const string title    = "\\$FFF" + Icons::Arrows + "\\$G Leaderboard Timestamps";

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting category="General" name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

void Main() {
    while (true) {
        yield();

        menuOpen = false;
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
    if (UI::Begin(title, S_Enabled, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoTitleBar)) {
        UI::Text(name);
    }
    UI::End();
}
