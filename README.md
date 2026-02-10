![](https://img.shields.io/badge/Signed-Yes-00AA00)
![](https://img.shields.io/badge/dynamic/json?query=downloads&url=https%3A%2F%2Fopenplanet.dev%2Fapi%2Fplugin%2F570&label=Downloads&color=purple)
![](https://img.shields.io/badge/dynamic/json?query=version&url=https%3A%2F%2Fopenplanet.dev%2Fapi%2Fplugin%2F570&label=Version&color=red)
![](https://img.shields.io/badge/Game-TM-blue)

# Leaderboard Timestamps

Shows a timestamp on the in-game records panel when you hover over someone's name. Works for all regions, your pinned club, club VIPs, and other VIPs (though I'm not sure what these actually are).

Automatically refreshes when:
- entering a map
- a new PB is set
- the records panel is refreshed (i.e. with the [Refresh Leaderboards](https://openplanet.dev/plugin/refreshleaderboard) plugin)

There are also settings available to customize how the displayed tooltip appears.

Known issues:
- If someone is knocked off of the records panel (someone else drove a better time than them) and this plugin is refreshed without the records panel being refreshed, their timestamp will no longer be shown.
- If your pinned club has many VIPs (like 180+) then a request will probably fail.

![image](images/leaderboard-timestamps.png)
