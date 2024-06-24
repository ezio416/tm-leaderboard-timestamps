// c 2024-06-24
// m 2024-06-24

[Setting hidden] bool   S_Enabled         = true;
[Setting hidden] bool   S_HideWithOP      = false;
[Setting hidden] bool   S_Timestamp       = true;
[Setting hidden] string S_TimestampFormat = "%Y-%m-%d $AAA@ $G%H:%M:%S $AAA(%a)";
[Setting hidden] bool   S_Recency         = true;

[SettingsTab name="General" icon="Cogs"]
void Settings_General() {
    if (UI::Button("Reset to default")) {
        Meta::PluginSetting@[]@ settings = Meta::ExecutingPlugin().GetSettings();

        for (uint i = 0; i < settings.Length; i++)
            settings[i].Reset();
    }

    S_Enabled = UI::Checkbox("Enabled", S_Enabled);
    S_HideWithOP = UI::Checkbox("Show/hide with Openplanet UI", S_HideWithOP);

    UI::Separator();

    S_Timestamp = UI::Checkbox("Show timestamp", S_Timestamp);
    HoverTooltipSetting("Shown in your local time");
    if (S_Timestamp) {
        S_TimestampFormat = UI::InputText("Timestamp format", S_TimestampFormat);
        HoverTooltipSetting("Uses strftime and supports Maniaplanet-style formatting\n(any \"$\" symbol will be used for this)");

        UI::Text("Preview: " + UnixToIso(Time::Stamp));

        if (UI::Button(Icons::ExternalLink + " Time formatting"))
            OpenBrowserURL("https://www.ibm.com/docs/en/workload-automation/10.2.0?topic=troubleshooting-date-time-format-reference-strftime");
        HoverTooltip("Open in browser");

        UI::SameLine();
        if (UI::Button(Icons::ExternalLink + " Color formatting"))
            OpenBrowserURL("https://doc.maniaplanet.com/client/text-formatting");
        HoverTooltip("Open in browser");
    }

    UI::Separator();

    S_Recency = UI::Checkbox("Show recency", S_Recency);
    HoverTooltipSetting("How long ago run was driven");
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

    UI::BeginDisabled(getting);
    if (UI::Button(Icons::Refresh + " Force refresh"))
        startnew(GetTimestampsAsync);
    UI::EndDisabled();
    HoverTooltipSetting("You shouldn't ever need to use this, but it's here just in case.\nIf you do, please report it to the plugin author!");

    if (UI::BeginTable("##table-debug", 5, UI::TableFlags::RowBg | UI::TableFlags::ScrollY)) {
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.0f, 0.0f, 0.0f, 0.5f));

        UI::TableSetupScrollFreeze(0, 1);
        UI::TableSetupColumn("account ID",     UI::TableColumnFlags::WidthFixed, scale * 260.0f);
        UI::TableSetupColumn("account name");
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

                UI::TableNextRow();

                UI::TableNextColumn();
                if (UI::Selectable(account.id, false, UI::SelectableFlags::SpanAllColumns))
                    OpenBrowserURL("https://trackmania.io/#/player/" + account.id);
                HoverTooltip(Icons::ExternalLink + " Trackmania.io");

                UI::TableNextColumn();
                UI::Text(account.name);

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
