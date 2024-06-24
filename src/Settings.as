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

    UI::Separator();

    UI::BeginDisabled(getting);
    if (UI::Button(Icons::Refresh + " Force refresh"))
        startnew(GetTimestampsAsync);
    UI::EndDisabled();
    HoverTooltipSetting("You shouldn't ever need to use this, but it's here just in case.\nIf you do, please report it to the plugin author!");
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
