// tf2c_b4dm_music.nut
// TF2C DM Music Controller (server-side)
// - Play WAIT while TF is actually in waiting-for-players.
// - Play MAIN as soon as waiting-for-players is no longer active.
// - Late joiners: on player_team/player_spawn, play the track that matches the
//   current gamerules waiting state instead of assuming they were present at map load.
// - Stop on round end/win/stalemate/game_over.
//
// TF2C notes:
// - StopSoundOn signature: StopSoundOn(soundName, entity)
// - RunScriptCode executes in root scope: anything it touches must be in root (::).

if (!IsServer())
    return;

// ---------------- Root constants (RunScriptCode-safe) ----------------
::B4DM_SOUND_WAIT <- "Deathmatch.B4DM_AFG_Wait";
::B4DM_SOUND_MAIN <- "Deathmatch.B4DM_AFG";
::B4DM_WAIT_TO_MAIN_SECONDS <- 30.0;
::B4DM_CVAR_MUSIC <- "tf2c_dm_music";

// ---------------- Persistent root state (do NOT reset on re-exec) ----------------
if (!("B4DM_Music" in getroottable()))
{
    ::B4DM_Music <-
    {
        state = "none",            // "none" | "wait" | "main"
        waitStartToken = 0,
        waitStartArmed = false,
        eventsRegistered = false
    };
}

if (!("B4DM_PlayerTrackState" in getroottable()))
    ::B4DM_PlayerTrackState <- {};

// ---------------- Small helpers ----------------
function B4DM_RegisterConVars()
{
    if (!("__b4dmConvarsReady" in getroottable()))
        ::__b4dmConvarsReady <- false;
    if (!("__b4dmMusicDefault" in getroottable()))
        ::__b4dmMusicDefault <- 1;

    if (::__b4dmConvarsReady)
        return;

    ::__b4dmConvarsReady = true;

    if (!("Convars" in getroottable()))
        return;

    try { Convars.RegisterConvar(::B4DM_CVAR_MUSIC, "1", "Enable DM music playback (1=allow, 0=disable).", 0); } catch (e0) {}
    try { Convars.RegisterConvar(::B4DM_CVAR_MUSIC, "1", "Enable DM music playback (1=allow, 0=disable)."); } catch (e1) {}
    try { Convars.RegisterConvar(::B4DM_CVAR_MUSIC, 1, "Enable DM music playback (1=allow, 0=disable).", 0); } catch (e2) {}
}

function B4DM_MusicEnabled()
{
    B4DM_RegisterConVars();

    local v = 1;
    if ("Convars" in getroottable())
    {
        try { v = Convars.GetInt(::B4DM_CVAR_MUSIC); } catch (e0) {}
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetFloat(::B4DM_CVAR_MUSIC).tointeger(); } catch (e1) {}
        }
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetStr(::B4DM_CVAR_MUSIC).tointeger(); } catch (e2) {}
        }
    }
    else
    {
        v = ::__b4dmMusicDefault;
    }

    return (v != 0);
}

function B4DM_ForEachPlayer(funcCallback)
{
    local playerEnt = null;
    while ((playerEnt = Entities.FindByClassname(playerEnt, "player")) != null)
    {
        if (playerEnt == null) continue;
        funcCallback(playerEnt);
    }
}

function B4DM_IsHumanPlayer(playerEnt)
{
    if (playerEnt == null)
        return false;

    try
    {
        if ("IsFakeClient" in playerEnt)
            return !playerEnt.IsFakeClient();
    }
    catch (e0) {}

    try
    {
        if ("GetNetworkIDString" in playerEnt)
        {
            local networkId = playerEnt.GetNetworkIDString();
            if (networkId == "BOT")
                return false;
        }
    }
    catch (e1) {}

    return true;
}

function B4DM_IsRealTeamPlayer(playerEnt)
{
    return (playerEnt != null && playerEnt.GetTeam() >= 1 && B4DM_IsHumanPlayer(playerEnt));
}

function B4DM_CountRealTeamPlayers()
{
    local count = 0;
    B4DM_ForEachPlayer(function(p) {
        if (B4DM_IsRealTeamPlayer(p)) count++;
    });
    return count;
}

function B4DM_StopOnPlayer(playerEnt)
{
    if (playerEnt == null)
        return;

    // TF2C: StopSoundOn(soundName, entity)
    StopSoundOn(::B4DM_SOUND_WAIT, playerEnt);
    StopSoundOn(::B4DM_SOUND_MAIN, playerEnt);

    local entIndex = -1;
    try { entIndex = playerEnt.entindex(); } catch (e0) { entIndex = -1; }
    if (entIndex >= 0 && entIndex in ::B4DM_PlayerTrackState)
        delete ::B4DM_PlayerTrackState[entIndex];
}

function B4DM_ClearTrackState(playerEnt)
{
    if (playerEnt == null)
        return;

    local entIndex = -1;
    try { entIndex = playerEnt.entindex(); } catch (e0) { entIndex = -1; }
    if (entIndex >= 0 && entIndex in ::B4DM_PlayerTrackState)
        delete ::B4DM_PlayerTrackState[entIndex];
}

function B4DM_PlayOnPlayer(playerEnt, soundName, forceRestart = false)
{
    if (!B4DM_MusicEnabled()) return;
    if (!B4DM_IsRealTeamPlayer(playerEnt)) return;

    local entIndex = -1;
    try { entIndex = playerEnt.entindex(); } catch (e0) { entIndex = -1; }
    if (!forceRestart && entIndex >= 0 && entIndex in ::B4DM_PlayerTrackState && ::B4DM_PlayerTrackState[entIndex] == soundName)
        return;

    B4DM_StopOnPlayer(playerEnt);

    local params =
    {
        sound_name = soundName,
        entity = playerEnt,
        channel = CHAN_STATIC,
        volume = 1.0,
        pitch = 100,
        soundlevel = SNDLVL_NONE
    };

    EmitSoundEx(params);

    if (entIndex >= 0)
        ::B4DM_PlayerTrackState[entIndex] <- soundName;
}

function B4DM_PlayCurrentForPlayer(playerEnt)
{
    if (!B4DM_IsRealTeamPlayer(playerEnt)) return;

    if (::B4DM_Music.state == "wait")
        B4DM_PlayOnPlayer(playerEnt, ::B4DM_SOUND_WAIT);
    else if (::B4DM_Music.state == "main")
        B4DM_PlayOnPlayer(playerEnt, ::B4DM_SOUND_MAIN);
}

function B4DM_ForceRefreshPlayer(playerEnt)
{
    if (!B4DM_IsRealTeamPlayer(playerEnt))
        return;

    B4DM_ClearTrackState(playerEnt);
    B4DM_StopOnPlayer(playerEnt);
    if (::B4DM_Music.state == "wait")
        B4DM_PlayOnPlayer(playerEnt, ::B4DM_SOUND_WAIT, true);
    else if (::B4DM_Music.state == "main")
        B4DM_PlayOnPlayer(playerEnt, ::B4DM_SOUND_MAIN, true);
}

function B4DM_ScheduleForceRefresh(playerEnt, delay, suffix)
{
    if (playerEnt == null)
        return;

    local entIndex = -1;
    try { entIndex = playerEnt.entindex(); } catch (e0) { entIndex = -1; }
    if (entIndex < 0)
        return;

    try
    {
        playerEnt.SetContextThink("B4DM_ForceRefresh_" + entIndex + "_" + suffix, function()
        {
            try { B4DM_ForceRefreshPlayer(playerEnt); } catch (e1) {}
            return null;
        }, delay);
    }
    catch (e2) {}
}

function B4DM_SynchronizePlayers()
{
    if (::B4DM_Music.state != "wait" && ::B4DM_Music.state != "main")
        return;

    local expectedSound = (::B4DM_Music.state == "wait") ? ::B4DM_SOUND_WAIT : ::B4DM_SOUND_MAIN;
    B4DM_ForEachPlayer(function(p) {
        if (!B4DM_IsRealTeamPlayer(p))
            return;

        local entIndex = -1;
        try { entIndex = p.entindex(); } catch (e0) { entIndex = -1; }
        if (entIndex < 0 || !(entIndex in ::B4DM_PlayerTrackState) || ::B4DM_PlayerTrackState[entIndex] != expectedSound)
            B4DM_PlayOnPlayer(p, expectedSound, true);
    });
}

function B4DM_StopAll()
{
    B4DM_ForEachPlayer(function(p) { B4DM_StopOnPlayer(p); });

    ::B4DM_Music.state = "none";
    ::B4DM_Music.waitStartArmed = false;
    ::B4DM_Music.waitStartToken++; // invalidate any pending fallback
}

function B4DM_PlayWaitForAllRealTeamPlayers()
{
    B4DM_ForEachPlayer(function(p) {
        if (B4DM_IsRealTeamPlayer(p))
            B4DM_PlayOnPlayer(p, ::B4DM_SOUND_WAIT);
    });

    ::B4DM_Music.state = "wait";
}

function B4DM_PlayMainForAllRealTeamPlayers()
{
    B4DM_ForEachPlayer(function(p) {
        if (B4DM_IsRealTeamPlayer(p))
            B4DM_PlayOnPlayer(p, ::B4DM_SOUND_MAIN);
    });

    ::B4DM_Music.state = "main";
    ::B4DM_Music.waitStartArmed = false;
    ::B4DM_Music.waitStartToken++; // invalidate pending fallback
}

function B4DM_Evaluate()
{
    if (!B4DM_MusicEnabled())
    {
        if (::B4DM_Music.state != "none")
            B4DM_StopAll();
        return;
    }

    // No real-team players -> stop.
    if (B4DM_CountRealTeamPlayers() < 1)
    {
        if (::B4DM_Music.state != "none")
            B4DM_StopAll();
        return;
    }

    local waitingForPlayers = false;
    try
    {
        if ("IsInWaitingForPlayers" in getroottable())
            waitingForPlayers = IsInWaitingForPlayers();
    }
    catch (e0) { waitingForPlayers = false; }

    if (waitingForPlayers)
    {
        if (::B4DM_Music.state != "wait")
            B4DM_PlayWaitForAllRealTeamPlayers();
        return;
    }

    if (::B4DM_Music.state != "main")
        B4DM_PlayMainForAllRealTeamPlayers();
}

// ---------------- Root-safe fallback scheduling ----------------
function B4DM_ArmWaitToMainFallback()
{
    if (::B4DM_Music.waitStartArmed) return;
    if (::B4DM_Music.state != "wait") return;

    ::B4DM_Music.waitStartArmed = true;
    ::B4DM_Music.waitStartToken++;

    local token = ::B4DM_Music.waitStartToken;

    local worldEnt = Entities.FindByClassname(null, "worldspawn");
    if (worldEnt == null) return;

    local code = "::B4DM_WaitToMainFallback(" + token + ")";
    EntFireByHandle(worldEnt, "RunScriptCode", code, ::B4DM_WAIT_TO_MAIN_SECONDS, null, null);
}

// Must be root for RunScriptCode. Root-safe: does not call non-root helpers.
::B4DM_WaitToMainFallback <- function(token)
{
    if (token != ::B4DM_Music.waitStartToken) return;
    if (::B4DM_Music.state != "wait") return;

    // Root-safe cvar check (avoid calling non-root helpers from RunScriptCode callback).
    local musicEnabled = true;
    if ("Convars" in getroottable())
    {
        local v = 1;
        try { v = Convars.GetInt(::B4DM_CVAR_MUSIC); } catch (e0) {}
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetFloat(::B4DM_CVAR_MUSIC).tointeger(); } catch (e1) {}
        }
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetStr(::B4DM_CVAR_MUSIC).tointeger(); } catch (e2) {}
        }
        musicEnabled = (v != 0);
    }
    if (!musicEnabled)
    {
        local pStop = null;
        while ((pStop = Entities.FindByClassname(pStop, "player")) != null)
        {
            if (pStop == null) continue;
            StopSoundOn(::B4DM_SOUND_WAIT, pStop);
            StopSoundOn(::B4DM_SOUND_MAIN, pStop);
            local stopEntIndex = -1;
            try { stopEntIndex = pStop.entindex(); } catch (eStopIdx) { stopEntIndex = -1; }
            if (stopEntIndex >= 0 && stopEntIndex in ::B4DM_PlayerTrackState)
                delete ::B4DM_PlayerTrackState[stopEntIndex];
        }
        ::B4DM_Music.state = "none";
        ::B4DM_Music.waitStartArmed = false;
        ::B4DM_Music.waitStartToken++;
        return;
    }

    // Only switch if at least one real-team player still exists.
    local realTeamCount = 0;
    local playerEnt = null;
    while ((playerEnt = Entities.FindByClassname(playerEnt, "player")) != null)
    {
        if (playerEnt == null) continue;

        local isHuman = true;
        try
        {
            if ("IsFakeClient" in playerEnt)
                isHuman = !playerEnt.IsFakeClient();
        }
        catch (eBot0) {}
        if (isHuman)
        {
            try
            {
                if ("GetNetworkIDString" in playerEnt && playerEnt.GetNetworkIDString() == "BOT")
                    isHuman = false;
            }
            catch (eBot1) {}
        }

        if (isHuman && playerEnt.GetTeam() >= 1)
            realTeamCount++;
    }

    if (realTeamCount < 1)
        return;

    // Switch everyone on real teams to MAIN (root-safe)
    playerEnt = null;
    while ((playerEnt = Entities.FindByClassname(playerEnt, "player")) != null)
    {
        if (playerEnt == null) continue;
        if (playerEnt.GetTeam() < 1) continue;

        local isHuman = true;
        try
        {
            if ("IsFakeClient" in playerEnt)
                isHuman = !playerEnt.IsFakeClient();
        }
        catch (eBot2) {}
        if (isHuman)
        {
            try
            {
                if ("GetNetworkIDString" in playerEnt && playerEnt.GetNetworkIDString() == "BOT")
                    isHuman = false;
            }
            catch (eBot3) {}
        }
        if (!isHuman) continue;

        StopSoundOn(::B4DM_SOUND_WAIT, playerEnt);
        StopSoundOn(::B4DM_SOUND_MAIN, playerEnt);

        local params =
        {
            sound_name = ::B4DM_SOUND_MAIN,
            entity = playerEnt,
            channel = CHAN_STATIC,
            volume = 1.0,
            pitch = 100,
            soundlevel = SNDLVL_NONE
        };

        EmitSoundEx(params);

        local entIndex = -1;
        try { entIndex = playerEnt.entindex(); } catch (eIdx) { entIndex = -1; }
        if (entIndex >= 0)
            ::B4DM_PlayerTrackState[entIndex] <- ::B4DM_SOUND_MAIN;
    }

    ::B4DM_Music.state = "main";
    ::B4DM_Music.waitStartArmed = false;
    ::B4DM_Music.waitStartToken++; // invalidate any other pending fallback
};

// ---------------- Event callbacks ----------------
function B4DM_OnPlayerSpawn(params)
{
    if (("bot" in params) && params.bot)
        return;

    B4DM_Evaluate();

    // Late joiners: play current track for that spawning player
    if (!("userid" in params)) return;

    local playerEnt = null;
    try { playerEnt = GetPlayerFromUserID(params.userid); } catch (e) { playerEnt = null; }
    B4DM_ForceRefreshPlayer(playerEnt);
    B4DM_ScheduleForceRefresh(playerEnt, 0.25, "spawn_a");
    B4DM_ScheduleForceRefresh(playerEnt, 1.00, "spawn_b");
    B4DM_ScheduleForceRefresh(playerEnt, 2.50, "spawn_c");
}

function B4DM_OnPlayerTeam(params)
{
    if (("bot" in params) && params.bot)
        return;

    B4DM_Evaluate();

    // Late joiners / team switches: play current track if they joined a real team
    if (!("userid" in params)) return;

    local playerEnt = null;
    try { playerEnt = GetPlayerFromUserID(params.userid); } catch (e) { playerEnt = null; }
    B4DM_ForceRefreshPlayer(playerEnt);
    B4DM_ScheduleForceRefresh(playerEnt, 0.25, "team_a");
    B4DM_ScheduleForceRefresh(playerEnt, 1.00, "team_b");
    B4DM_ScheduleForceRefresh(playerEnt, 2.50, "team_c");
}

function B4DM_OnPlayerActivate(params)
{
    if (("bot" in params) && params.bot)
        return;

    if (!("userid" in params)) return;
    local playerEnt = null;
    try { playerEnt = GetPlayerFromUserID(params.userid); } catch (e) { playerEnt = null; }
    B4DM_ForceRefreshPlayer(playerEnt);
    B4DM_ScheduleForceRefresh(playerEnt, 0.25, "activate_a");
    B4DM_ScheduleForceRefresh(playerEnt, 1.00, "activate_b");
    B4DM_ScheduleForceRefresh(playerEnt, 2.50, "activate_c");
}

function B4DM_OnPlayerDisconnect(params)
{
    if ("userid" in params)
    {
        local playerEnt = null;
        try { playerEnt = GetPlayerFromUserID(params.userid); } catch (e0) { playerEnt = null; }
        if (playerEnt != null)
            B4DM_StopOnPlayer(playerEnt);
    }
    B4DM_Evaluate();
}

function B4DM_OnRoundStart(params)
{
    // WaitingForPlayers is over: force transition to match-loop music.
    // Keep this key-safe (no optional table keys) so round-start cannot throw.
    B4DM_PlayMainForAllRealTeamPlayers();
    B4DM_ForEachPlayer(function(p) { B4DM_PlayCurrentForPlayer(p); });
}

function B4DM_OnRoundEnd(params)
{
    // Keep your previous “stop at end” behavior.
    B4DM_StopAll();
}

function B4DM_MusicThink()
{
    B4DM_Evaluate();
    B4DM_SynchronizePlayers();
    return 0.50;
}

// ---------------- Init (idempotent) ----------------
function B4DM_Init()
{
    B4DM_RegisterConVars();
    try { PrecacheSound(::B4DM_SOUND_WAIT); } catch (eP0) {}
    try { PrecacheSound(::B4DM_SOUND_MAIN); } catch (eP1) {}

    // If the file is re-executed by the game, do not reset state or re-register events.
    if (::B4DM_Music.eventsRegistered)
    {
        // Resync: ensure current track is applied to real-team players.
        local worldEnt = Entities.FindByClassname(null, "worldspawn");
        if (worldEnt != null)
            worldEnt.SetContextThink("B4DM_MusicThink", B4DM_MusicThink, 0.10);
        B4DM_Evaluate();
        B4DM_ForEachPlayer(function(p) { B4DM_PlayCurrentForPlayer(p); });
        return;
    }

    ::B4DM_Music.eventsRegistered = true;

    ListenToGameEvent("player_spawn",      "B4DM_OnPlayerSpawn",      "");
    ListenToGameEvent("player_team",       "B4DM_OnPlayerTeam",       "");
    ListenToGameEvent("player_activate",   "B4DM_OnPlayerActivate",   "");
    ListenToGameEvent("player_disconnect", "B4DM_OnPlayerDisconnect", "");
    ListenToGameEvent("teamplay_round_start", "B4DM_OnRoundStart", "");

    ListenToGameEvent("teamplay_round_win",       "B4DM_OnRoundEnd", "");
    ListenToGameEvent("teamplay_round_stalemate", "B4DM_OnRoundEnd", "");
    ListenToGameEvent("teamplay_game_over",       "B4DM_OnRoundEnd", "");

    local worldEnt = Entities.FindByClassname(null, "worldspawn");
    if (worldEnt != null)
        worldEnt.SetContextThink("B4DM_MusicThink", B4DM_MusicThink, 0.10);

    B4DM_Evaluate();
}

function Activate()
{
    B4DM_Init();
}

function main()
{
    Activate();
}

Activate();
