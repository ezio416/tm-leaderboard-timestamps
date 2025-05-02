// c 2024-06-24
// m 2025-05-01

[Setting hidden] bool   S_Enabled          = true;
[Setting hidden] Font   S_Font             = Font::DroidSansBold;
[Setting hidden] vec4   S_FontColor        = vec4(1.0f, 1.0f, 1.0f, 0.25f);
[Setting hidden] int    S_FontSize         = 14;
[Setting hidden] bool   S_HideWithOP       = false;
[Setting hidden] bool   S_InitV2           = false;
[Setting hidden] bool   S_Legacy           = false;
[Setting hidden] bool   S_Recency          = true;
[Setting hidden] float  S_RecencyOffsetX   = 0.0f;
[Setting hidden] float  S_RecencyOffsetY   = 0.0f;
[Setting hidden] bool   S_RecencyLargest   = false;
[Setting hidden] bool   S_Timestamp        = true;
[Setting hidden] string S_TimestampFormat  = "%Y-%m-%d @ %H:%M:%S (%a)";
[Setting hidden] float  S_TimestampOffsetX = 0.0f;
[Setting hidden] float  S_TimestampOffsetY = 0.0f;
[Setting hidden] bool   S_Warning          = true;
// add hover enlarge thing for small resolutions

[SettingsTab name="General" icon="Cogs"]
void Settings_General() {
    if (UI::Button("Reset to default")) {
        Meta::PluginSetting@[]@ settings = Meta::ExecutingPlugin().GetSettings();

        for (uint i = 0; i < settings.Length; i++)
            settings[i].Reset();
    }

    S_Enabled = UI::Checkbox("Enabled", S_Enabled);
    S_HideWithOP = UI::Checkbox("Show/hide with Openplanet UI", S_HideWithOP);
    S_Legacy = UI::Checkbox("Legacy mode", S_Legacy);
    HoverTooltipSetting("Shows a tooltip like how it used to be (less laggy)");
    S_Warning = UI::Checkbox("Warn when a record is driven but won't upload right away", S_Warning);
    HoverTooltipSetting(
        "Records only upload if you have author medal, get a new medal, or exit the map."
    );

    if (!S_Legacy) {
        UI::Separator();

        if (UI::BeginCombo("Font style", tostring(S_Font))) {
            for (uint i = 0; i < int(Font::_Count); i++) {
                const Font f = Font(i);
                if (UI::Selectable(tostring(f), S_Font == f)) {
                    S_Font = f;
                    OnSettingsChanged();
                }
            }

            UI::EndCombo();
        }

        const int fontSize = S_FontSize;
        S_FontSize = UI::InputInt("Font size", S_FontSize);
        if (S_FontSize != fontSize)
            OnSettingsChanged();

        S_FontColor = UI::InputColor4("Font color", S_FontColor);
    }

    UI::Separator();

    S_Timestamp = UI::Checkbox("Show timestamp", S_Timestamp);
    HoverTooltipSetting("Shown in your local time");
    if (S_Timestamp) {
        if (!S_Legacy) {
            S_TimestampOffsetX = UI::InputFloat("Offset X##ts", S_TimestampOffsetX);
            S_TimestampOffsetY = UI::InputFloat("Offset Y##ts", S_TimestampOffsetY);
        }

        S_TimestampFormat = UI::InputText("Format", S_TimestampFormat);
        HoverTooltipSetting("Uses strftime" + (S_Legacy ? " and supports Maniaplanet-style formatting\n(any \"$\" symbol will be used for this)" : ""));

        UI::Text("Preview: " + UnixToIso(Time::Stamp));

        if (UI::Button(Icons::ExternalLink + " Time formatting"))
            OpenBrowserURL("https://www.ibm.com/docs/en/workload-automation/10.2.0?topic=troubleshooting-date-time-format-reference-strftime");
        HoverTooltip("Open in browser");

        if (S_Legacy) {
            UI::SameLine();
            if (UI::Button(Icons::ExternalLink + " Color formatting"))
                OpenBrowserURL("https://doc.maniaplanet.com/client/text-formatting");
            HoverTooltip("Open in browser");
        }
    }

    UI::Separator();

    S_Recency = UI::Checkbox("Show recency", S_Recency);
    HoverTooltipSetting("How long ago run was driven");
    if (S_Recency) {
        if (!S_Legacy) {
            S_RecencyOffsetX = UI::InputFloat("Offset X##rc", S_RecencyOffsetX);
            S_RecencyOffsetY = UI::InputFloat("Offset Y##rc", S_RecencyOffsetY);
        }

        S_RecencyLargest = UI::Checkbox("Only show largest value", S_RecencyLargest);
        HoverTooltipSetting("i.e. '17h 53m 04s' gets shortened to '17h'");
    }
}

[SettingsTab name="Debug" icon="Bug" order=1]
void Settings_Debug() {
    if (mapUid.Length > 0) {
        if (UI::Selectable("map UID: " + mapUid, false))
            OpenBrowserURL("https://trackmania.io/#/leaderboard/" + mapUid);
        HoverTooltip(Icons::ExternalLink + " Trackmania.io");
    } else
        UI::Text("map UID: none");

    if (pinnedClub > 0) {
        if (UI::Selectable("pinned club: " + pinnedClub, false))
            OpenBrowserURL("https://trackmania.io/#/clubs/" + pinnedClub);
        HoverTooltip(Icons::ExternalLink + " Trackmania.io");
    } else
        UI::Text("pinned club: none");

    UI::Text("accountsQueue: " + accountsQueue.Length);
    UI::Text("total accounts: " + accountsById.GetSize());
    UI::Text("getting data: " + getting);
    UI::Text("new local PB: " + newLocalPb);

    UI::BeginDisabled(getting);
    if (UI::Button(Icons::Refresh + " Force refresh"))
        startnew(GetTimestampsAsync);
    UI::EndDisabled();
    HoverTooltipSetting("You shouldn't ever need to use this, but it's here just in case.\nIf you do, please report it to the plugin author!");

    if (UI::BeginTable("##table-debug", 6, UI::TableFlags::RowBg | UI::TableFlags::ScrollY)) {
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.0f, 0.0f, 0.0f, 0.5f));

        UI::TableSetupScrollFreeze(0, 1);
        UI::TableSetupColumn("account ID",     UI::TableColumnFlags::WidthFixed, scale * 260.0f);
        UI::TableSetupColumn("account name");
        UI::TableSetupColumn("time",           UI::TableColumnFlags::WidthFixed, scale * 80.0f);
        UI::TableSetupColumn("ts (epoch)",     UI::TableColumnFlags::WidthFixed, scale * 80.0f);
        UI::TableSetupColumn("ts (formatted)", UI::TableColumnFlags::WidthFixed, Draw::MeasureString(UnixToIso(1727265600)).x);
        UI::TableSetupColumn("recency",        UI::TableColumnFlags::WidthFixed, scale * 100.0f);
        UI::TableHeadersRow();

        const int64 now = Time::Stamp;

        string[]@ accountIds = accountsById.GetKeys();

        UI::ListClipper clipper(accountIds.Length);
        while (clipper.Step()) {
            for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                Account@ account = cast<Account@>(accountsById[accountIds[i]]);
                if (account is null) {
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("\\$F00null account");
                    break;
                }

                UI::TableNextRow();

                UI::TableNextColumn();
                if (UI::Selectable(account.id, false, UI::SelectableFlags::SpanAllColumns))
                    OpenBrowserURL("https://trackmania.io/#/player/" + account.id);
                HoverTooltip(Icons::ExternalLink + " Trackmania.io");

                UI::TableNextColumn();
                UI::Text(account.name);

                UI::TableNextColumn();
                UI::Text(Time::Format(account.time));

                UI::TableNextColumn();
                UI::Text(tostring(account.timestamp));

                UI::TableNextColumn();
                UI::Text(UnixToIso(account.timestamp));

                UI::TableNextColumn();
                UI::Text(FormatSeconds(now - account.timestamp));
            }
        }

        UI::PopStyleColor();
        UI::EndTable();
    }
}

void HoverTooltipSetting(const string &in msg) {
    UI::SameLine();
    UI::Text("\\$666" + Icons::QuestionCircle);
    if (!UI::IsItemHovered())
        return;

    UI::SetNextWindowSize(int(Math::Min(Draw::MeasureString(msg).x, 400.0f)), 0.0f);
    UI::BeginTooltip();
    UI::TextWrapped(msg);
    UI::EndTooltip();
}
