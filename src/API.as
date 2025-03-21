// c 2024-06-24
// m 2025-03-21

void GetAccountsAsync() {
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
}

Net::HttpRequest@ GetAsync(const string &in audience, const string &in endpoint) {
    sleep(waitTime);

    Net::HttpRequest@ req = NadeoServices::Get(audience, endpoint);
    req.Start();
    while (!req.Finished())
        yield();

    return req;
}

void GetClubAsync(const string &in funcName, const string &in endpoint) {
    if (pinnedClub == 0)
        return;

    Log::Info("starting", funcName);

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return;
    }

    if (GetTopFrom(req.Json()))
        Log::Info("success", funcName);
    else
        Log::Warn("failed", funcName);
}

void GetClubSurroundAsync() {
    GetClubAsync(
        "GetClubSurroundAsync",
        "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/surround/1/1"
    );
}

void GetClubTopAsync() {
    GetClubAsync(
        "GetClubTopAsync",
        "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/top"
    );
}

void GetClubVIPsAsync() {
    if (pinnedClub == 0 || !hasClubVip)
        return;

    GetVIPsAsync(
        "GetClubVIPsAsync",
        "/api/token/club/" + pinnedClub + "/vip/map/" + mapUid + "?seasonUid=Personal_Best"
    );
}

Net::HttpRequest@ GetCoreAsync(const string &in endpoint) {
    return GetAsync(audienceCore, NadeoServices::BaseURLCore() + endpoint);
}

Net::HttpRequest@ GetLiveAsync(const string &in endpoint) {
    return GetAsync(audienceLive, NadeoServices::BaseURLLive() + endpoint);
}

string GetMapIdAsync() {
    const string funcName = "GetMapIdAsync";

    Log::Info("starting", funcName);

    Net::HttpRequest@ req = GetCoreAsync("/maps/?mapUidList=" + mapUid);

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return "";
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return "";

    if (parsed.Length == 0) {
        Log::Warn("parsed is empty", funcName);
        return "";
    }

    Json::Value@ map = parsed[0];
    if (!JsonIsObject(map, funcName + ": map"))
        return "";

    if (!map.HasKey("mapId")) {
        Log::Warn("map missing key 'mapId'", funcName);
        return "";
    }

    const string mapId = string(map["mapId"]);

    Log::Info("success", funcName);

    return mapId;
}

void GetPlayerClubInfoAsync() {
    const string funcName = "GetPlayerClubInfoAsync";

    Log::Info("starting", funcName);

    Net::HttpRequest@ req = GetLiveAsync("/api/token/club/player/info");

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("hasClubVip")) {
        Log::Warn("parsed missing key 'hasClubVip'", funcName);
        return;
    }

    hasClubVip = bool(parsed["hasClubVip"]);

    if (!parsed.HasKey("hasPlayerVip")) {
        Log::Warn("parsed missing key 'hasPlayerVip'", funcName);
        return;
    }

    hasPlayerVip = bool(parsed["hasPlayerVip"]);

    if (!parsed.HasKey("pinnedClub")) {
        Log::Warn("parsed missing key 'pinnedClub'", funcName);
        return;
    }

    pinnedClub = uint(parsed["pinnedClub"]);

    Log::Info("success", funcName);
}

void GetPlayerVIPsAsync() {
    if (!hasPlayerVip)
        return;

    GetVIPsAsync(
        "GetPlayerVIPsAsync",
        "/api/token/club/player-vip/map/" + mapUid + "?seasonUid=Personal_Best"
    );
}

void GetRecordsAsync() {
    const string funcName = "GetRecordsAsync";

    Log::Info("starting", funcName);

    if (mapId.Length == 0)
        mapId = GetMapIdAsync();
    if (mapId.Length == 0) {
        Log::Warn("mapId blank", funcName);
        return;
    }

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    const bool stunt = true
        && App.RootMap !is null
        && string(App.RootMap.MapType).Contains("TM_Stunt")
    ;

    // todo: account for many club VIPs
    Net::HttpRequest@ req = GetCoreAsync(
        "/v2/mapRecords/?accountIdList=" + string::Join(accountsById.GetKeys(), "%2C") + "&mapId=" + mapId
        + (stunt ? "&gameMode=Stunt" : "")
    );

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return;

    if (parsed.Length == 0) {
        Log::Warn("parsed is empty", funcName);
        return;
    }

    for (uint i = 0; i < parsed.Length; i++) {
        Log::Debug("record " + i, funcName);

        Json::Value@ record = parsed[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            Log::Warn("record " + i + " missing key 'accountId'", funcName);
            continue;
        }

        const string accountId = record["accountId"];
        Account@ account = cast<Account@>(accountsById[accountId]);
        if (account is null) {
            Log::Warn("null account", funcName);
            continue;
        }

        if (!record.HasKey("timestamp")) {
            Log::Warn("record " + i + " missing key 'timestamp'", funcName);
            continue;
        }

        const string timestampIso = string(record["timestamp"]);
        account.timestamp = Time::ParseFormatString("%FT%T", timestampIso);

        if (!record.HasKey("recordScore")) {
            Log::Warn("record " + i + " missing key 'recordScore'", funcName);
            continue;
        }

        Json::Value@ recordScore = record["recordScore"];
        if (!JsonIsObject(recordScore, funcName + ": recordScore " + i))
            continue;

        if (!recordScore.HasKey("time")) {
            Log::Warn("recordScore " + i + " missing key 'time'", funcName);
            continue;
        }

        account.time = uint(recordScore["time"]);
        Log::Debug("time " + i + " " + account.time, funcName);

        if (account.self) {
            const uint _pb = GetPersonalBest();
            Log::Debug("_pb " + _pb + ", account.time " + account.time, funcName);
            if (true
                && _pb != uint(-1)
                && _pb != 0
                && _pb != account.time
            ) {
                Log::Warn(
                    "local pb (" + Time::Format(_pb) + ") does not match api (" + Time::Format(account.time) + ")",
                    funcName
                );
                Log::Debug("setting newLocalPb true", funcName);
                newLocalPb = true;
            }
        }
    }

    if (!accountsById.Exists(playerId)) {
        Account@ me = Account(playerId);
        accountsById.Set(playerId, @me);
        accountsByName.Set(playerName, @me);

        me.time = GetPersonalBest();
        Log::Debug("me.time: " + Time::Format(me.time), funcName);

        if (true
            && me.time != uint(-1)
            && me.time != 0
        ) {
            Log::Warn(
                "local pb (" + Time::Format(me.time) + ") is not uploaded",
                funcName
            );
            Log::Debug(
                "setting newLocalPb true because my account was not found",
                funcName
            );
            newLocalPb = true;
        }
    }

    Log::Debug("success", funcName);
}

void GetRegionsAsync(const string &in funcName, const string &in endpoint) {
    Log::Info("starting", funcName);

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("tops")) {
        Log::Warn("parsed missing key 'tops'", funcName);
        return;
    }

    Json::Value@ tops = parsed["tops"];
    if (!JsonIsArray(tops, funcName + ": tops"))
        return;

    if (tops.Length == 0) {
        Log::Warn("tops is empty", funcName);
        return;
    }

    for (uint i = 0; i < tops.Length; i++)
        GetTopFrom(tops[i]);

    Log::Info("success", funcName);
}

void GetRegionsSurroundAsync() {
    GetRegionsAsync(
        "GetRegionsSurroundAsync",
        "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1"
    );
}

void GetRegionsTopAsync() {
    GetRegionsAsync(
        "GetRegionsTopAsync",
        "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top"
    );
}

void GetVIPsAsync(const string &in funcName, const string &in endpoint) {
    Log::Info("starting", funcName);

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        Log::Warn(
            "code: " + code + " | error: " + req.Error() + " | resp: " + req.String(),
            funcName
        );
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("accountIdList")) {
        Log::Warn("parsed missing key 'accountIdList'", funcName);
        return;
    }

    Json::Value@ accounts = parsed["accountIdList"];
    if (!JsonIsArray(accounts, funcName + ": accounts"))
        return;

    if (accounts.Length == 0) {
        Log::Warn("accounts is empty", funcName);
        return;
    }

    for (uint i = 0; i < accounts.Length; i++)
        HandleAccountId(accounts[i]);

    Log::Info("success", funcName);
}
