// c 2024-06-24
// m 2024-07-10

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

    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("top")) {
        warn(funcName + ": parsed missing key 'top'");
        return;
    }

    Json::Value@ top = parsed["top"];
    if (!JsonIsArray(top, funcName + ": top"))
        return;

    if (top.Length == 0) {
        warn(funcName + ": top is empty");
        return;
    }

    for (uint i = 0; i < top.Length; i++) {
        Json::Value@ record = top[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn(funcName + ": record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = string(record["accountId"]);

        if (!accountsById.Exists(accountId)) {
            accountsById[accountId] = Account(accountId);
            accountsQueue.InsertLast(accountId);
        }
    }

    trace(funcName + ": success");
}

void GetClubSurroundAsync() {
    GetClubAsync("GetClubSurroundAsync", "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/surround/1/1");
}

void GetClubTopAsync() {
    GetClubAsync("GetClubTopAsync", "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/club/" + pinnedClub + "/top");
}

void GetClubVIPsAsync() {
    if (pinnedClub == 0 || !hasClubVip)
        return;

    GetVIPsAsync("GetClubVIPsAsync", "/api/token/club/" + pinnedClub + "/vip/map/" + mapUid + "?seasonUid=Personal_Best");
}

Net::HttpRequest@ GetCoreAsync(const string &in endpoint) {
    return GetAsync(audienceCore, NadeoServices::BaseURLCore() + endpoint);
}

Net::HttpRequest@ GetLiveAsync(const string &in endpoint) {
    return GetAsync(audienceLive, NadeoServices::BaseURLLive() + endpoint);
}

string GetMapIdAsync() {
    const string funcName = "GetMapIdAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetCoreAsync("/maps/?mapUidList=" + mapUid);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return "";
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return "";

    if (parsed.Length == 0) {
        warn(funcName + ": parsed is empty");
        return "";
    }

    Json::Value@ map = parsed[0];
    if (!JsonIsObject(map, funcName + ": map"))
        return "";

    if (!map.HasKey("mapId")) {
        warn(funcName + ": map missing key 'mapId'");
        return "";
    }

    const string mapId = string(map["mapId"]);

    trace(funcName + ": success");

    return mapId;
}

void GetPlayerClubInfoAsync() {
    const string funcName = "GetPlayerClubInfoAsync";
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync("/api/token/club/player/info");

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("hasClubVip")) {
        warn(funcName + ": parsed missing key 'hasClubVip'");
        return;
    }

    hasClubVip = bool(parsed["hasClubVip"]);

    if (!parsed.HasKey("hasPlayerVip")) {
        warn(funcName + ": parsed missing key 'hasPlayerVip'");
        return;
    }

    hasPlayerVip = bool(parsed["hasPlayerVip"]);

    if (!parsed.HasKey("pinnedClub")) {
        warn(funcName + ": parsed missing key 'pinnedClub'");
        return;
    }

    pinnedClub = uint(parsed["pinnedClub"]);

    trace(funcName + ": success");
}

void GetPlayerVIPsAsync() {
    if (!hasPlayerVip)
        return;

    GetVIPsAsync("GetPlayerVIPsAsync", "/api/token/club/player-vip/map/" + mapUid + "?seasonUid=Personal_Best");
}

void GetRecordsAsync() {
    const string funcName = "GetRecordsAsync";
    trace(funcName + ": starting");

    const string mapId = GetMapIdAsync();
    if (mapId.Length == 0) {
        warn(funcName + ": mapId blank");
        return;
    }

    // todo: account for many club VIPs
    Net::HttpRequest@ req = GetCoreAsync("/mapRecords/?accountIdList=" + string::Join(accountsById.GetKeys(), "%2C") + "&mapIdList=" + mapId);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn("req (records): code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsArray(parsed, funcName + ": parsed"))
        return;

    if (parsed.Length == 0) {
        warn(funcName + ": parsed is empty");
        return;
    }

    for (uint i = 0; i < parsed.Length; i++) {
        Json::Value@ record = parsed[i];
        if (!JsonIsObject(record, funcName + ": record " + i))
            continue;

        if (!record.HasKey("accountId")) {
            warn(funcName + ": record " + i + " missing key 'accountId'");
            continue;
        }

        const string accountId = record["accountId"];

        if (!record.HasKey("timestamp")) {
            warn(funcName + ": record " + i + " missing key 'timestamp'");
            continue;
        }

        const string timestampIso = string(record["timestamp"]);
        const int64 timestamp = IsoToUnix(timestampIso);

        Account@ account = cast<Account@>(accountsById[accountId]);
        if (account is null)
            continue;

        account.timestamp = timestamp;
        // print(account);
    }

    trace(funcName + ": success");
}

void GetRegionsAsync(const string &in funcName, const string &in endpoint) {
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("tops")) {
        warn(funcName + ": parsed missing key 'tops'");
        return;
    }

    Json::Value@ tops = parsed["tops"];
    if (!JsonIsArray(tops, funcName + ": tops"))
        return;

    if (tops.Length == 0) {
        warn(funcName + ": tops is empty");
        return;
    }

    for (uint i = 0; i < tops.Length; i++) {
        Json::Value@ region = tops[i];
        if (!JsonIsObject(region, funcName + ": region " + i))
            continue;

        if (!region.HasKey("top")) {
            warn(funcName + ": region " + i + " missing key 'top'");
            continue;
        }

        Json::Value@ regionTop = region["top"];
        if (!JsonIsArray(regionTop, funcName + ": regionTop " + i))
            continue;

        for (uint j = 0; j < regionTop.Length; j++) {
            Json::Value@ record = regionTop[j];
            if (!JsonIsObject(record, funcName + ": record " + i + " " + j))
                continue;

            if (!record.HasKey("accountId")) {
                warn(funcName + ": record " + i + " " + j + " missing key 'accountId'");
                continue;
            }

            const string accountId = string(record["accountId"]);

            if (!accountsById.Exists(accountId)) {
                accountsById[accountId] = Account(accountId);
                accountsQueue.InsertLast(accountId);
            }
        }
    }

    trace(funcName + ": success");
}

void GetRegionsSurroundAsync() {
    GetRegionsAsync("GetRegionsSurroundAsync", "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1");
}

void GetRegionsTopAsync() {
    GetRegionsAsync("GetRegionsTopAsync", "/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top");
}

void GetVIPsAsync(const string &in funcName, const string &in endpoint) {
    trace(funcName + ": starting");

    Net::HttpRequest@ req = GetLiveAsync(endpoint);

    const int code = req.ResponseCode();
    if (code != 200) {
        warn(funcName + ": code: " + code + " | error: " + req.Error() + " | resp: " + req.String());
        return;
    }

    Json::Value@ parsed = req.Json();
    if (!JsonIsObject(parsed, funcName + ": parsed"))
        return;

    if (!parsed.HasKey("accountIdList")) {
        warn(funcName + ": parsed missing key 'accountIdList'");
        return;
    }

    Json::Value@ accounts = parsed["accountIdList"];
    if (!JsonIsArray(accounts, funcName + ": accounts"))
        return;

    if (accounts.Length == 0) {
        warn(funcName + ": accounts is empty");
        return;
    }

    for (uint i = 0; i < accounts.Length; i++) {
        const string accountId = string(accounts[i]);

        if (!accountsById.Exists(accountId)) {
            accountsById[accountId] = Account(accountId);
            accountsQueue.InsertLast(accountId);
        }
    }

    trace(funcName + ": success");
}
