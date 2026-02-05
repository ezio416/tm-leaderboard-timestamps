class Account {
    string id;
    string name;
    uint   time      = uint(-1);
    int64  timestamp = 0;
    int    rank      = -1;

    bool get_self() {
        return id == playerId;
    }

    Account() { }
    Account(const string&in id) {
        this.id = id;
    }

    string ToString() {
        return "Account ( id: " + id + ", name: " + name + ", time: " + time + ", ts: " + timestamp + " )";
    }
}
