void RenderAll(CGameManialinkPage@ RecordsTable) {
    if (true
        and !S_Timestamp
        and !S_Recency
    ) {
        return;
    }

    auto GlobalFrame = cast<CGameManialinkFrame>(RecordsTable.GetFirstChild("frame-global"));
    if (false
        or GlobalFrame is null
        or !GlobalFrame.Visible
    ) {
        return;
    }

    auto RankingFrame = cast<CGameManialinkFrame>(RecordsTable.GetFirstChild("frame-ranking"));
    if (false
        or RankingFrame is null
        or !RankingFrame.Visible
    ) {
        @RankingFrame = cast<CGameManialinkFrame>(RecordsTable.GetFirstChild("scroll-ranking"));  // VIPs
    }
    if (false
        or RankingFrame is null
        or !RankingFrame.Visible
    ) {
        return;
    }

    nvg::FontFace(font);
    nvg::FillColor(S_FontColor);
    nvg::FontSize(S_FontSize);

    for (uint i = 0; i < RankingFrame.Controls.Length and i < 9; i++) {
        RenderRanking(RankingFrame.Controls[i]);
    }
}

void RenderLegacy(CGameManialinkPage@ RecordsTable) {
    if (menuOpen) {
        return;
    }

    auto Focused = cast<CGameManialinkQuad>(RecordsTable.FocusedControl);
    if (false
        or Focused is null
        or !Focused.Visible
        or Focused.Parent is null
    ) {
        return;
    }

    auto NameLabel = cast<CGameManialinkLabel>(
        Focused.Parent.GetFirstChild("cmgame-player-name_label-name")
    );
    if (false
        or NameLabel is null
        or NameLabel.Value.Length == 0
    ) {
        return;
    }

    const string name = string(NameLabel.Value);
    if (name.StartsWith("\u0092")) {
        return;
    }

    UI::BeginTooltip();

    if (true
        and newLocalPb
        and name == playerName
    ) {
        UI::Text("\\$A00Record not uploaded yet!\nGet a new medal or exit the map.");

    } else if (true
        and !S_Timestamp
        and !S_Recency
    ) {
        UI::Text("\\$FA0Enable an option in the settings!");

    } else {
        if (!accountsByName.Exists(name)) {
            UI::Text(legacyLoadText);
        }

        else {
            auto account = cast<Account>(accountsByName[name]);
            if (account.timestamp < 1) {
                UI::Text(legacyLoadText);
            }

            else {
                if (S_Timestamp) {
                    UI::Text(UnixToIso(account.timestamp));
                }

                if (S_Recency) {
                    UI::Text(FormatSeconds(Time::Stamp - account.timestamp) + " ago");
                }
            }
        }
    }

    UI::EndTooltip();
}

void RenderRanking(CGameManialinkControl@ control) {
    auto frame = cast<CGameManialinkFrame>(control);
    if (false
        or frame is null
        or !frame.Visible
    ) {
        return;
    }

    auto NameLabel = cast<CGameManialinkLabel>(
        frame.GetFirstChild("cmgame-player-name_label-name")
    );
    if (false
        or NameLabel is null
        or NameLabel.Value.Length == 0
    ) {
        return;
    }

    Account@ account;
    const string name = string(NameLabel.Value);

    if (true
        and !getting
        and name == playerName
        and !accountsById.Exists(playerId)
    ) {
        // warn("setting newLocalPb true in render");
        // newLocalPb = true;

        // print("creating my account");

        // @account = Account(playerId);
        // account.name = playerName;
        // account.time = pb;
        // accountsById.Set(playerId, @account);
        // accountsByName.Set(playerName, @account);

    } else if (accountsByName.Exists(name)) {
        @account = cast<Account>(accountsByName[name]);
    }

    const float w       = Math::Max(1, Display::GetWidth());
    const float h       = Math::Max(1, Display::GetHeight());
    const vec2  center  = vec2(w * 0.5f, h * 0.5f);
    const float unit    = (w / h < stdRatio) ? w / 320.0f : h / 180.0f;
    const vec2  scale   = vec2(unit, -unit);
    const vec2  basePos = center + scale * NameLabel.AbsolutePosition_V3;

    const bool newLocal = true
        and newLocalPb
        and name == playerName
    ;

    if (false
        or account is null
        or (true
            and !newLocal
            and account.timestamp == 0
        )
    ) {
        return;
    }

    if (S_Timestamp) {
        nvg::Text(
            basePos + vec2(S_TimestampOffsetX, S_TimestampOffsetY),
            newLocal
                ? "not uploaded yet"
                : TimeFormatString(
                    Text::StripFormatCodes(S_TimestampFormat),
                    account.timestamp
                )
        );
    }

    if (S_Recency) {
        nvg::Text(
            basePos + vec2(S_RecencyOffsetX, S_RecencyOffsetY),
            newLocal
                ? "not uploaded yet"
                : FormatSeconds(Time::Stamp - account.timestamp) + " ago"
        );
    }
}

CGameManialinkPage@ FindScoresTable(CGameManiaAppPlayground@ CMAP) {
    for (uint i = 0; i < CMAP.UILayers.Length; i++) {
        CGameUILayer@ layer = CMAP.UILayers[i];
        if (layer is null) continue;
        if (layer.Type != CGameUILayer::EUILayerType::Normal) continue;
        if (layer.ManialinkPageUtf8.Length == 0) continue;
        int start = layer.ManialinkPageUtf8.IndexOf("<");
        int end = layer.ManialinkPageUtf8.IndexOf(">");
        if (start < 0 || end < 0) continue;
        string tag = layer.ManialinkPageUtf8.SubStr(start, end);
        if (tag.Contains("_Race_ScoresTable")) {
            return layer.LocalPage;
        }
    }
    return null;
}

void RenderScores(CGameManialinkPage@ page) {
    if (menuOpen) return;

    CGameManialinkControl@ focused = page.FocusedControl;
    if (false
        or focused is null
        or !focused.Visible
    ) {
        return;
    }

    CGameManialinkControl@ parent = focused.Parent;
    if (parent is null) return;
    auto frame = cast<CGameManialinkFrame>(parent);
    if (frame is null) return;
    auto nameLabel = cast<CGameManialinkLabel>(frame.GetFirstChild("cmgame-player-name_label-name"));
    if (nameLabel is null) return;
    if (nameLabel.Value.Length == 0) return;
    string rawName = string(nameLabel.Value);
    string key = SanitizeName(rawName);
    if (pbByName.Exists(key)) {
        auto pbObj = pbByName[key];
        auto pb = cast<PBTime>(pbObj);
        if (pb !is null) {
            UI::BeginTooltip();

            // Always show PB time
            if (pb.time > 0) {
                UI::Text("PB: " + pb.timeStr);
            } else {
                UI::Text("PB: No record on this map");
            }

            // Show global position if available
            if (pb.globalPosition > 0) {
                UI::Text("Global Rank: " + FormatPosition(pb.globalPosition));
            }

            // Show delta from WR if available
            if (pb.deltaFromWRStr.Length > 0) {
                UI::Text("Delta from WR: " + pb.deltaFromWRStr);
            }

            UI::EndTooltip();
        }
    }
}
