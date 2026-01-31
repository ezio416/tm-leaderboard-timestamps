class PBTime {
    string name;
    uint time;
    string timeStr;
    
    // Leaderboard data
    uint globalPosition = 0;
    uint worldRecord = 0;
    int deltaFromWR = 0;
    string deltaFromWRStr = "";
    
    PBTime() {}
    PBTime(const string &in _name, uint _time) {
        name = _name;
        time = _time;
        timeStr = FormatPBTime(time);
    }
    
    int opCmp(const PBTime@ other) const {
        if (time == 0) {
            return other.time == 0 ? 0 : 1;
        }
        if (other.time == 0) return -1;
        if (time < other.time) return -1;
        if (time > other.time) return 1;
        return 0;
    }
}