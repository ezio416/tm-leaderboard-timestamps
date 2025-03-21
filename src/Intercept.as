// c 2025-03-20
// m 2025-03-20

const string CYAN     = "\\$0FD";
const string DARKGRAY = "\\$777";  // trace
const string DARKRED  = "\\$A00";
const string GREEN    = "\\$0F6";
const string ORANGE   = "\\$FA0";
const string RESET    = "\\$G";

// class Request {
//     uint   id;
//     string result;
//     string url;

//     Request(CNetScriptHttpRequest@ req) {
//         id     = req.Id.Value;
//         result = req.Result;
//         url    = req.Url;
//     }
// }

bool clubSurround   = false;
bool clubTop        = false;
bool clubVip        = false;
bool regionSurround = false;
bool regionTop      = false;
bool vip            = false;

bool GetTopFrom(Json::Value@ region) {
    if (!JsonIsObject(region, "region"))
        return false;

    Json::Value@ top = region["top"];
    if (!JsonIsArray(top, "top"))
        return false;

    for (uint i = 0; i < top.Length; i++) {
        Json::Value@ player = top[i];
        if (JsonIsObject(player, "player"))
            HandleAccountId(player["accountId"]);
    }

    return true;
}

bool HandleAccountId(Json::Value@ accountId) {
    if (!CheckJsonType(accountId, Json::Type::String, "accountId"))
        return false;

    const string id = string(accountId);
    if (id.Length != 36) {
        Log::Warn("bad accountId: " + id);
        return false;
    }

    if (!accountsById.Exists(id)) {
        accountsById[id] = Account(id);
        accountsQueue.InsertLast(id);
    }

    return true;
}

namespace Intercept {
    bool active = false;
    bool getting = false;

    bool Destroy(CMwStack &in stack, CMwNod@ nod) {
        const string funcName = "Intercept::Destroy";

        CTrackMania@ App = cast<CTrackMania@>(GetApp());
        if (App.RootMap is null)
            return true;

        Log::Debug(
            DARKRED + "============================== Intercept::Destroy ==============================",
            funcName
        );

        CNetScriptHttpRequest@ req;
        try {
            @req = cast<CNetScriptHttpRequest@>(stack.CurrentNod());
        } catch {
            Log::Warn(getExceptionInfo(), funcName);
        }

        if (req is null) {
            Log::Warn("null request", funcName);
            return true;
        }

        if (!req.IsCompleted || req.StatusCode != 200) {
            Log::Warn(
                "bad request: url: " + req.Url + " | complete: " + req.IsCompleted
                    + " | code: " + req.StatusCode + " | result: " + req.Result,
                funcName
            );
            return true;
        }

        const string baseUrlLive = NadeoServices::BaseURLLive() + "/api/token";
        if (!req.Url.StartsWith(baseUrlLive))
            return true;

        const string result = string(req.Result);

        string endpoint = req.Url.Replace(baseUrlLive, "");
        Log::Debug(ORANGE + "live endpoint: " + endpoint, funcName);
        Log::Debug(ORANGE + "result: " + result.Replace("\n", "\\n"), funcName);

        Json::Value@ parsed = Json::Parse(result);
        if (!JsonIsObject(parsed, "parsed"))
            return true;

        string filename;

        if (endpoint.StartsWith("/club")) {
            if (endpoint.StartsWith("/club/player-vip")) {
                vip = true;
                filename = "player-vip";

            } else {
                string[]@ parts = endpoint.Split("/");
                if (parts.Length < 4) {
                    Log::Debug("endpoint too short: " + endpoint, funcName);
                    return true;
                }

                if (parts[3] == "vip") {
                    clubVip = true;
                    filename = "club-vip";

                } else
                    Log::Debug("unknown club endpoint: " + endpoint, funcName);
            }

            Json::Value@ accountIdList = parsed["accountIdList"];
            if (!JsonIsArray(accountIdList, "accountIdList"))
                return true;

            for (uint i = 0; i < accountIdList.Length; i++)
                HandleAccountId(accountIdList[i]);

        } else if (endpoint.StartsWith("/leaderboard/group/Personal_Best/map")) {
            endpoint = endpoint.Replace("/leaderboard/group/Personal_Best/map", "");
            endpoint = endpoint.Replace("/" + App.RootMap.EdChallengeId, "");
            // print("endpoint lb " + endpoint);

            if (endpoint.StartsWith("/club")) {
                if (endpoint.EndsWith("/top")) {
                    clubTop = true;
                    filename = "club-top";

                } else if (endpoint.EndsWith("/surround/1/1")) {
                    clubSurround = true;
                    filename = "club-surround";

                } else
                    Log::Debug("unknown club leaderboard endpoint: " + endpoint, funcName);

                GetTopFrom(parsed);

            } else {
                if (endpoint.EndsWith("/top")) {
                    regionTop = true;
                    filename = "region-top";

                } else if (endpoint.EndsWith("/surround/1/1")) {
                    regionSurround = true;
                    filename = "region-surround";

                } else
                    Log::Debug("unknown leaderboard endpoint: " + endpoint, funcName);

                Json::Value@ tops = parsed["tops"];
                if (!JsonIsArray(tops, "tops"))
                    return true;

                for (uint i = 0; i < tops.Length; i++)
                    GetTopFrom(tops[i]);
            }

        } else
            Log::Debug("unknown endpoint: " + endpoint, funcName);

        if (filename.Length > 0) {
            Json::ToFile(
                // IO::FromStorageFolder(filename + "_" + Time::Now + ".json"),
                IO::FromStorageFolder(filename + ".json"),
                parsed,
                true
            );
        }

        return true;
    }

    // void GetRequestsAsync(ref@ m) {
    //     CNetScriptHttpManager@ Mgr = cast<CNetScriptHttpManager@>(m);
    //     if (Mgr is null) {
    //         warn("Mgr is null");
    //         return;
    //     }

    //     print("GetRequests found " + Mgr.Requests.Length);

    //     for (uint i = 0; i < Mgr.Requests.Length; i++) {
    //         CNetScriptHttpRequest@ req = Mgr.Requests[i];
    //         if (req !is null) {
    //             Request@ request = Request(req);

    //             if (requestIds.Find(request.id) == -1) {
    //                 print("\\$F0F" + request.url + " " + ORANGE + request.result);
    //                 requests.InsertLast(@request);
    //                 requestIds.InsertLast(request.id);
    //             }
    //         }
    //     }

    //     // while (Mgr.Requests.Length > 0) {
    //     //     yield();
    //     //     print(Mgr.Requests.Length);
    //     // }

    //     getting = false;
    // }

    bool HttpGet(CMwStack &in stack, CMwNod@ nod) {
        const string funcName = "Intercept::HttpGet";

        Log::Debug(
            GREEN + "============================== Intercept::HttpGet ==============================",
            funcName
        );

        string headers;
        string url;
        bool   useCache;

        int available = stack.Count() - stack.Index() - 1;
        Log::Debug(CYAN + "available: " + available, funcName);

        switch (available) {
            case 1:
                url = stack.CurrentString(0);
                Log::Debug(CYAN + "url: " + url, funcName);

                break;

            case 2:
                url = stack.CurrentString(0);
                Log::Debug(CYAN + "url: " + url, funcName);

                useCache = stack.CurrentBool(0);
                Log::Debug(CYAN + "useCache: " + useCache, funcName);

                break;

            case 3:
                url = stack.CurrentString(2);
                Log::Debug(CYAN + "url: " + url, funcName);

                useCache = stack.CurrentBool(1);
                Log::Debug(CYAN + "useCache: " + useCache, funcName);

                headers = stack.CurrentString(0);
                Log::Debug(CYAN + "headers.Length (chars): " + headers.Length, funcName);
                // Log::Debug(CYAN + "headers: " + headers.Replace("\n", "\\n"), funcName);  // has player's auth

                break;

            default:;
        }

        // CNetScriptHttpManager@ Mgr = cast<CNetScriptHttpManager@>(nod);
        // if (Mgr is null)
        //     return true;

        // if (!getting) {
        //     getting = true;
        //     startnew(GetRequestsAsync, Mgr);
        // }
        // return true;

        // print("reqs: " + Mgr.Requests.Length + ", pend: " + Mgr.PendingEvents.Length);

        // for (uint i = 0; i < Mgr.Requests.Length; i++) {
        //     CNetScriptHttpRequest@ req = Mgr.Requests[i];
        //     if (req !is null) {
        //         print(ORANGE + "url: " + req.Url + " | code: " + req.StatusCode + " | result: " + string(req.Result).Replace("\n", "\\n"));

        //         // HttpRequest@ request = HttpRequest(req);
        //         // bool dupe = false;

        //         // for (int j = requests.Length - 1; j >= 0; j--) {
        //         //     if (requests[j].id.Value == request.id.Value) {
        //         //         dupe = true;
        //         //         break;
        //         //     }
        //         //     if (Time::Stamp - requests[j].sentAt > 60)
        //         //         break;
        //         // }

        //         // if (dupe) {
        //         //     // warn("already have req: " + request.url);
        //         // } else if (capturing) {
        //         //     print("adding req: " + request.url);
        //         //     requests.InsertLast(@request);
        //         // }

        //     } else
        //         warn("null req");
        // }

        // for (uint i = 0; i < Mgr.PendingEvents.Length; i++) {
        //     CNetScriptHttpEvent@ event = Mgr.PendingEvents[i];
        //     if (event !is null) {
        //         // print(ORANGE + "event: " + event.IdName);
        //     } else
        //         warn("null event");
        // }

        return true;
    }

    void Init() {
        const string funcName = "Intercept::Init";

        if (active) {
            Log::Warn("already active", funcName);
            return;
        }

        try {
            Dev::InterceptProc("CNetScriptHttpManager", "CreateGet3", HttpGet);
            active = true;
        } catch {
            Log::Warn("CreateGet3: " + getExceptionInfo(), funcName);
        }

        try {
            Dev::InterceptProc("CNetScriptHttpManager", "Destroy", Destroy);
        } catch {
            Log::Warn("Destroy: " + getExceptionInfo(), funcName);
            Intercept::Reset();
        }
    }

    void Reset() {
        const string funcName = "Intercept::Reset";

        if (!active) {
            Log::Warn("not active", funcName);
            return;
        }

        try {
            Dev::ResetInterceptProc("CNetScriptHttpManager", "CreateGet3");
            active = false;
        } catch {
            Log::Warn("CreateGet3: " + getExceptionInfo(), funcName);
        }

        try {
            Dev::ResetInterceptProc("CNetScriptHttpManager", "Destroy");
        } catch {
            active = true;
            Log::Warn("Destroy: " + getExceptionInfo(), funcName);
        }
    }

    void Toggle() {
        if (active)
            Reset();
        else
            Init();
    }
}
