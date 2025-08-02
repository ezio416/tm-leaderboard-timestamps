// c 2025-08-02
// m 2025-08-02

namespace Intercept {
    bool gotTop          = false;
    bool gotClubTop      = false;
    bool gotSurround     = false;
    bool gotClubSurround = false;
    bool intercepting    = false;

    bool FuncDestroy(CMwStack&in stack) {
        auto req = cast<CNetScriptHttpRequest>(stack.CurrentNod());
        if (false
            or req is null
            or req.StatusCode != 200
            or !req.Url.StartsWith(NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/Personal_Best/map/" + mapUid)
        ) {
            return true;
        }

        print(req.Url);

        return true;
    }

    void Start() {
        if (!intercepting) {
            Dev::InterceptProc("CNetScriptHttpManager", "Destroy", FuncDestroy);
            intercepting = true;
        }
    }

    void Stop() {
        if (intercepting) {
            Dev::ResetInterceptProc("CNetScriptHttpManager", "Destroy");
            intercepting = false;
        }
    }
}
