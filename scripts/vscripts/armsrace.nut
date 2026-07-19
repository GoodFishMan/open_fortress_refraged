// armsrace.nut
// Main-branch Arms Race / Gun Game mode for Merc DM.

if (!("TF2C_ArmsRace_EventsRegistered" in getroottable()))
    ::TF2C_ArmsRace_EventsRegistered <- false;
if (!("TF2C_ArmsRace_Host" in getroottable()))
    ::TF2C_ArmsRace_Host <- null;
if (!("TF2C_ArmsRace_PlayerState" in getroottable()))
    ::TF2C_ArmsRace_PlayerState <- {};
if (!("TF2C_ArmsRace_RankHud" in getroottable()))
    ::TF2C_ArmsRace_RankHud <- {};
if (!("TF2C_ArmsRace_ClientCommandPoint" in getroottable()))
    ::TF2C_ArmsRace_ClientCommandPoint <- null;

const TF2C_ARMSRACE_TEAM_RED = 2;
const TF2C_ARMSRACE_TEAM_BLU = 3;
const TF2C_ARMSRACE_TEAM_GRN = 4;
const TF2C_ARMSRACE_TEAM_YLW = 5;

const TF2C_ARMSRACE_ITEMDEF_KNIFE = 4;
const TF2C_ARMSRACE_ITEMDEF_GOLDEN_KNIFE = 2022;

const TF2C_ARMSRACE_CHAT_COLOR_NORMAL = "\x01";
const TF2C_ARMSRACE_CHAT_COLOR_RED = "\x07FF4040";
const TF2C_ARMSRACE_CHAT_COLOR_BLUE = "\x0799CCFF";
const TF2C_ARMSRACE_CHAT_COLOR_GREEN = "\x0799FF99";
const TF2C_ARMSRACE_CHAT_COLOR_YELLOW = "\x07FFA000";

const TF2C_ARMSRACE_SOUND_DEMOTED = "ArmsRace.Demoted";
const TF2C_ARMSRACE_SOUND_LEVEL_UP = "ArmsRace.LevelUp";
const TF2C_ARMSRACE_SOUND_DEMOTED_WAVE = "ui/armsrace_demoted.wav";
const TF2C_ARMSRACE_SOUND_LEVEL_UP_WAVE = "ui/bell1.wav";
const TF2C_ARMSRACE_SOUND_DEMOTED_COMMAND = "play ui/armsrace_demoted.wav";
const TF2C_ARMSRACE_SOUND_LEVEL_UP_COMMAND = "play ui/bell1.wav";
const TF2C_ARMSRACE_SOUND_GOLDEN_KNIFE = "ArmsRace.Warning";
const TF2C_ARMSRACE_SNIPER_LEVEL = 12;
const TF2C_ARMSRACE_GLOW_MODE = 1;

::TF2C_ArmsRace_Ladder <- [
    { level = 1, itemDef = 2014, className = "tf2c_weapon_aagun", name = "Anti-Aircraft Cannon" },
    { level = 2, itemDef = 15, className = "tf_weapon_minigun", name = "Minigun" },
    { level = 3, itemDef = 18, className = "tf_weapon_rocketlauncher", name = "Rocket Launcher" },
    { level = 4, itemDef = 2002, className = "tf_weapon_rocketlauncher", name = "RPG" },
    { level = 5, itemDef = 2008, className = "tf_weapon_pipebomblauncher", name = "Mine Layer" },
    { level = 6, itemDef = 20, className = "tf_weapon_pipebomblauncher", name = "Stickybomb Launcher" },
    { level = 7, itemDef = 19, className = "tf_weapon_grenadelauncher", name = "Grenade Launcher" },
    { level = 8, itemDef = 2021, className = "tf2c_weapon_cyclops", name = "Cyclops" },
    { level = 9, itemDef = 21, className = "tf_weapon_flamethrower", name = "Flamethrower" },
    { level = 10, itemDef = 52, className = "tf_weapon_compound_bow", name = "Huntsman" },
    { level = 11, itemDef = 2003, className = "tf2c_weapon_hunting_revolver", name = "Hunting Revolver" },
    { level = 12, itemDef = 14, className = "tf_weapon_sniperrifle", name = "Sniper Rifle" },
    { level = 13, itemDef = 2013, className = "tf2c_weapon_doubleshotgun", name = "Super Shotgun" },
    { level = 14, itemDef = 10, className = "tf_weapon_shotgun_soldier", name = "Shotgun (Soldier)" },
    { level = 15, itemDef = 13, className = "tf_weapon_scattergun", name = "Scattergun" },
    { level = 16, itemDef = 16, className = "tf_weapon_smg", name = "Sten Gun" },
    { level = 17, itemDef = 2001, className = "tf2c_weapon_nailgun", name = "Nailgun" },
    { level = 18, itemDef = 17, className = "tf_weapon_syringegun_medic", name = "Syringe Gun" },
    { level = 19, itemDef = 22, className = "tf_weapon_pistol", name = "Pistol (Engineer)" },
    { level = 20, itemDef = 35, className = "tf_weapon_flaregun", name = "Flare Gun" },
    { level = 21, itemDef = 2007, className = "tf2c_weapon_coilgun", name = "Coilgun" },
    { level = 22, itemDef = 24, className = "tf_weapon_revolver", name = "Revolver (Spy)" },
    { level = 23, itemDef = 2005, className = "tf2c_weapon_tranq", name = "Tranquilizer" },
    { level = 24, itemDef = 2006, className = "tf_weapon_grenade_mirv", name = "MIRV" },
    { level = 25, itemDef = 2017, className = "tf2c_weapon_brick", name = "Brick" },
    { level = 26, itemDef = TF2C_ARMSRACE_ITEMDEF_GOLDEN_KNIFE, className = "tf_weapon_knife", name = "Golden Knife" },
];

function TF2C_ArmsRace_IsEnabled()
{
    local gamemode = 0;
    if ("Convars" in getroottable())
    {
        try { gamemode = Convars.GetInt("tf2c_dm_gamemode"); } catch (e0) { gamemode = 0; }
    }
    return (gamemode == 4);
}

function TF2C_ArmsRace_IsPlayablePlayer(player)
{
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return false;

    local team = 0;
    try { team = player.GetTeam(); } catch (e0) { team = 0; }
    return (team >= TF2C_ARMSRACE_TEAM_RED && team <= TF2C_ARMSRACE_TEAM_YLW);
}

function TF2C_ArmsRace_IsBotPlayer(player)
{
    if (player == null || !player.IsValid())
        return false;
    try
    {
        if ("__Merc_IsBotPlayer" in getroottable())
            return __Merc_IsBotPlayer(player);
    }
    catch (e0) {}
    try
    {
        if ("IsFakeClient" in player)
            return player.IsFakeClient();
    }
    catch (e1) {}
    return false;
}

function TF2C_ArmsRace_BotsSkipSniperEnabled()
{
    try
    {
        if ("__Merc_ArmsRaceBotsSkipSniperEnabled" in getroottable())
            return __Merc_ArmsRaceBotsSkipSniperEnabled();
    }
    catch (e0) {}
    return true;
}

function TF2C_ArmsRace_AdjustLevelForBot(player, level, direction)
{
    local adjusted = level;
    if (!TF2C_ArmsRace_IsBotPlayer(player) || !TF2C_ArmsRace_BotsSkipSniperEnabled())
        return adjusted;

    if (adjusted == TF2C_ARMSRACE_SNIPER_LEVEL)
    {
        if (direction > 0)
            adjusted = TF2C_ARMSRACE_SNIPER_LEVEL + 1;
        else if (direction < 0)
            adjusted = TF2C_ARMSRACE_SNIPER_LEVEL - 1;
    }

    if (adjusted < 1)
        adjusted = 1;
    if (adjusted > TF2C_ArmsRace_GetMaxLevel())
        adjusted = TF2C_ArmsRace_GetMaxLevel();
    return adjusted;
}

function TF2C_ArmsRace_GetPlayerEntIndex(player)
{
    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    return entIdx;
}

function TF2C_ArmsRace_GetPlayerName(player)
{
    if (player == null || !player.IsValid())
        return "Unknown";

    local name = "";
    try { name = NetProps.GetPropString(player, "m_szNetname"); } catch (e0) { name = ""; }
    if (name == null || name == "")
    {
        try
        {
            if ("GetPlayerName" in player)
                name = player.GetPlayerName();
        }
        catch (e1) { name = ""; }
    }
    if (name == null || name == "")
        name = "Unknown";
    return name;
}

function TF2C_ArmsRace_GetTeamColor(teamNum)
{
    if (teamNum == TF2C_ARMSRACE_TEAM_RED)
        return TF2C_ARMSRACE_CHAT_COLOR_RED;
    if (teamNum == TF2C_ARMSRACE_TEAM_BLU)
        return TF2C_ARMSRACE_CHAT_COLOR_BLUE;
    if (teamNum == TF2C_ARMSRACE_TEAM_GRN)
        return TF2C_ARMSRACE_CHAT_COLOR_GREEN;
    if (teamNum == TF2C_ARMSRACE_TEAM_YLW)
        return TF2C_ARMSRACE_CHAT_COLOR_YELLOW;
    return TF2C_ARMSRACE_CHAT_COLOR_NORMAL;
}

function TF2C_ArmsRace_GetTeamHudColorRGB(teamNum)
{
    if (teamNum == TF2C_ARMSRACE_TEAM_RED)
        return "255 64 64";
    if (teamNum == TF2C_ARMSRACE_TEAM_BLU)
        return "153 204 255";
    if (teamNum == TF2C_ARMSRACE_TEAM_GRN)
        return "153 255 153";
    if (teamNum == TF2C_ARMSRACE_TEAM_YLW)
        return "255 160 0";
    return "255 255 255";
}

function TF2C_ArmsRace_GetTeamGlowColorRGBA(teamNum)
{
    if (teamNum == TF2C_ARMSRACE_TEAM_RED)
        return "255 64 64 255";
    if (teamNum == TF2C_ARMSRACE_TEAM_BLU)
        return "153 204 255 255";
    if (teamNum == TF2C_ARMSRACE_TEAM_GRN)
        return "153 255 153 255";
    if (teamNum == TF2C_ARMSRACE_TEAM_YLW)
        return "255 160 0 255";
    return "255 255 255 255";
}

function TF2C_ArmsRace_GetState(player)
{
    local entIdx = TF2C_ArmsRace_GetPlayerEntIndex(player);
    if (entIdx < 0)
        return null;

    if (!(entIdx in ::TF2C_ArmsRace_PlayerState))
        ::TF2C_ArmsRace_PlayerState[entIdx] <- { level = 1, kills = 0, userid = -1 };
    try { ::TF2C_ArmsRace_PlayerState[entIdx].userid = player.GetUserID(); } catch (e0) {}
    return ::TF2C_ArmsRace_PlayerState[entIdx];
}

function TF2C_ArmsRace_ResetAllState()
{
    local player = null;
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!TF2C_ArmsRace_IsPlayablePlayer(player))
            continue;
        try { TF2C_ArmsRace_ClearGoldenKnifeGlow(player); } catch (e0) {}
    }
    ::TF2C_ArmsRace_PlayerState <- {};
}

function TF2C_ArmsRace_RemovePlayerStateByUserID(userID)
{
    foreach (entIdx, state in ::TF2C_ArmsRace_PlayerState)
    {
        if (!("userid" in state))
            continue;
        if (state.userid == userID)
        {
            delete ::TF2C_ArmsRace_PlayerState[entIdx];
            return;
        }
    }
}

function TF2C_ArmsRace_DestroyRankHudForEntIndex(entIdx)
{
    local key = entIdx.tostring();
    if (!(key in ::TF2C_ArmsRace_RankHud))
        return;

    local ent = ::TF2C_ArmsRace_RankHud[key];
    delete ::TF2C_ArmsRace_RankHud[key];
    if (ent == null)
        return;

    try { ent.Destroy(); } catch (e0) { try { ent.Kill(); } catch (e1) {} }
}

function TF2C_ArmsRace_EnsureGoldenKnifeGlow(player)
{
    return null;
}

function TF2C_ArmsRace_SetGoldenKnifeGlowEnabled(player, enabled)
{
    return;
}

function TF2C_ArmsRace_ClearGoldenKnifeGlow(player)
{
    return;
}

function TF2C_ArmsRace_ReapplyAllLoadouts()
{
    local player = null;
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!TF2C_ArmsRace_IsPlayablePlayer(player))
            continue;
        try { TF2C_ArmsRace_GiveLoadout(player); } catch (e0) {}
        try { TF2C_ArmsRace_UpdateRankHUD(player); } catch (e1) {}
    }
}

function TF2C_ArmsRace_GetLadderEntry(level)
{
    foreach (entry in ::TF2C_ArmsRace_Ladder)
    {
        if (entry.level == level)
            return entry;
    }
    return ::TF2C_ArmsRace_Ladder[0];
}

function TF2C_ArmsRace_GetMaxLevel()
{
    return ::TF2C_ArmsRace_Ladder.len();
}

function TF2C_ArmsRace_IsGoldenKnifeLevel(level)
{
    return (level >= TF2C_ArmsRace_GetMaxLevel());
}

function TF2C_ArmsRace_EnsureWeaponSupport()
{
    if ("GivePlayerWeapon" in getroottable() && "ApplyWeaponAmmoDefaults" in getroottable() && "ClearPlayerReserveAmmo" in getroottable())
        return true;

    try
    {
        if ("__LoadDMRando" in getroottable())
            __LoadDMRando();
    }
    catch (e0) {}

    if ("GivePlayerWeapon" in getroottable() && "ApplyWeaponAmmoDefaults" in getroottable() && "ClearPlayerReserveAmmo" in getroottable())
        return true;

    try
    {
        if ("DoIncludeScript" in getroottable())
            DoIncludeScript("tf2c_dmrando.nut", getroottable());
    }
    catch (e1) {}

    return ("GivePlayerWeapon" in getroottable() && "ApplyWeaponAmmoDefaults" in getroottable() && "ClearPlayerReserveAmmo" in getroottable());
}

function TF2C_ArmsRace_ClearWeaponSlot(player, slotIndex)
{
    if (player == null || !player.IsValid())
        return;

    if ("StripWeaponSlot" in getroottable())
    {
        try { StripWeaponSlot(player, slotIndex); } catch (e0) {}
    }

    if (!("NetProps" in getroottable()))
        return;

    for (local i = 0; i < 8; i++)
    {
        local held = null;
        try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e1) { held = null; }
        if (held == null)
            continue;

        local heldSlot = -2;
        try { heldSlot = held.GetSlot(); } catch (e2) { heldSlot = -2; }
        if (heldSlot != slotIndex)
            continue;

        try { held.Destroy(); } catch (e3) { try { held.Kill(); } catch (e4) {} }
        try { NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); } catch (e5) {}
    }
}

function TF2C_ArmsRace_EquipWeapon(player, weapon)
{
    if (player == null || !player.IsValid() || weapon == null || !weapon.IsValid())
        return;

    try { player.Weapon_Switch(weapon); } catch (e0) {}
    try { NetProps.SetPropEntity(player, "m_hActiveWeapon", weapon); } catch (e1) {}
}

function TF2C_ArmsRace_PlayClientSound(player, soundName, wavePath = null)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    if (wavePath != null && wavePath != "")
    {
        try { EmitSoundOnClient(wavePath, player); return; } catch (e0) {}
    }
    if (soundName != null && soundName != "")
    {
        try { EmitSoundOnClient(soundName, player); return; } catch (e1) {}
    }

    local fallbackName = null;
    if (wavePath != null && wavePath != "")
        fallbackName = wavePath;
    else if (soundName != null && soundName != "")
        fallbackName = soundName;
    if (fallbackName == null || fallbackName == "")
        return;

    try
    {
        local params = {
            sound_name = fallbackName,
            entity = player,
            speakerentity = player.entindex(),
            origin = player.GetOrigin(),
            channel = CHAN_STATIC,
            volume = 1.0,
            pitch = 100,
            soundlevel = 0
        };
        EmitSoundEx(params);
    }
    catch (e2) {}
}

function TF2C_ArmsRace_EnsureClientCommandPoint()
{
    if (::TF2C_ArmsRace_ClientCommandPoint != null)
    {
        try
        {
            if (::TF2C_ArmsRace_ClientCommandPoint.IsValid())
                return ::TF2C_ArmsRace_ClientCommandPoint;
        }
        catch (e0) {}
    }

    local ent = null;
    try { ent = Entities.CreateByClassname("point_clientcommand"); } catch (e1) { ent = null; }
    if (ent == null)
        return null;

    try
    {
        if ("DispatchSpawn" in ent)
            ent.DispatchSpawn();
    }
    catch (e2) {}

    ::TF2C_ArmsRace_ClientCommandPoint <- ent;
    return ent;
}

function TF2C_ArmsRace_PlayClientCommandSound(player, commandText)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player) || commandText == null || commandText == "")
        return;

    local cmdEnt = TF2C_ArmsRace_EnsureClientCommandPoint();
    if (cmdEnt == null)
        return;

    try { EntFireByHandle(cmdEnt, "Command", commandText, 0.0, player, player); } catch (e0) {}
}

function TF2C_ArmsRace_ScheduleClientFeedbackSound(player, soundName, wavePath, commandText, delay, suffix)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    local entIdx = TF2C_ArmsRace_GetPlayerEntIndex(player);
    if (entIdx < 0)
        return;

    try
    {
        player.SetContextThink("TF2C_ArmsRace_SoundRetry_" + entIdx + "_" + suffix, function()
        {
            try { TF2C_ArmsRace_PlayClientSound(player, soundName, wavePath); } catch (e0) {}
            try { TF2C_ArmsRace_PlayClientCommandSound(player, commandText); } catch (e1) {}
            return null;
        }, delay);
    }
    catch (e2) {}
}

function TF2C_ArmsRace_PlayGlobalSound(soundName)
{
    if (soundName == null || soundName == "")
        return;

    try
    {
        local evt = { team = 255, sound = soundName };
        SendGlobalGameEvent("teamplay_broadcast_audio", evt);
        return;
    }
    catch (e0) {}

    local player = null;
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!TF2C_ArmsRace_IsPlayablePlayer(player))
            continue;
        try { EmitSoundOnClient(soundName, player, player); continue; } catch (e1) {}
        try { EmitSoundOnClient(soundName, player); } catch (e2) {}
    }
}

function TF2C_ArmsRace_RefreshFallDamageState(player)
{
    if (player == null || !player.IsValid())
        return;

    try
    {
        if ("RemoveCustomAttribute" in player)
            player.RemoveCustomAttribute("cancel falling damage");
    }
    catch (e0) {}

    try
    {
        local shouldGrantNoFall = true;
        if ("__Merc_ShouldGrantNoFallDamage" in getroottable())
            shouldGrantNoFall = __Merc_ShouldGrantNoFallDamage();
        if (shouldGrantNoFall)
        {
            if ("AddCustomAttribute" in player)
                player.AddCustomAttribute("cancel falling damage", 1, -1);
        }
    }
    catch (e1) {}
}

function TF2C_ArmsRace_ScheduleFallDamageRefresh(player)
{
    if (player == null || !player.IsValid())
        return;

    local entIdx = TF2C_ArmsRace_GetPlayerEntIndex(player);
    if (entIdx < 0)
        return;

    try
    {
        player.SetContextThink("TF2C_ArmsRace_FallRefresh_" + entIdx, function()
        {
            try { TF2C_ArmsRace_RefreshFallDamageState(player); } catch (e0) {}
            return null;
        }, 0.05);
    }
    catch (e1) {}

    try
    {
        player.SetContextThink("TF2C_ArmsRace_FallRefreshLate_" + entIdx, function()
        {
            try { TF2C_ArmsRace_RefreshFallDamageState(player); } catch (e2) {}
            return null;
        }, 0.15);
    }
    catch (e3) {}

    try
    {
        player.SetContextThink("TF2C_ArmsRace_FallRefreshLater_" + entIdx, function()
        {
            try { TF2C_ArmsRace_RefreshFallDamageState(player); } catch (e4) {}
            return null;
        }, 0.35);
    }
    catch (e5) {}

    try
    {
        player.SetContextThink("TF2C_ArmsRace_FallRefreshLatest_" + entIdx, function()
        {
            try { TF2C_ArmsRace_RefreshFallDamageState(player); } catch (e6) {}
            return null;
        }, 0.75);
    }
    catch (e7) {}
}

function TF2C_ArmsRace_GetRankHudEntity(player)
{
    local entIdx = TF2C_ArmsRace_GetPlayerEntIndex(player);
    if (entIdx < 0)
        return null;

    local key = entIdx.tostring();
    local ent = null;
    if (key in ::TF2C_ArmsRace_RankHud)
    {
        ent = ::TF2C_ArmsRace_RankHud[key];
        if (ent != null && ent.IsValid())
            return ent;
        delete ::TF2C_ArmsRace_RankHud[key];
    }

    try
    {
        local state = TF2C_ArmsRace_GetState(player);
        local levelText = "Level 1/" + TF2C_ArmsRace_GetMaxLevel().tostring();
        if (state != null)
            levelText = "Level " + state.level.tostring() + "/" + TF2C_ArmsRace_GetMaxLevel().tostring();
        local colorText = TF2C_ArmsRace_GetTeamHudColorRGB(player.GetTeam()) + " 255";
        ent = SpawnEntityFromTable("game_text",
        {
            targetname = "armsrace_rank_hud_" + key,
            channel = 4,
            color = colorText,
            color2 = colorText,
            effect = 0,
            fadein = 0.0,
            fadeout = 0.0,
            fxtime = 0.0,
            holdtime = 9999.0,
            message = levelText,
            spawnflags = 0,
            x = 0.01,
            y = 0.42
        });
    }
    catch (e0) { ent = null; }

    if (ent != null)
        ::TF2C_ArmsRace_RankHud[key] <- ent;
    return ent;
}

function TF2C_ArmsRace_UpdateRankHUD(player)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    local state = TF2C_ArmsRace_GetState(player);
    if (state == null)
        return;

    local hud = TF2C_ArmsRace_GetRankHudEntity(player);
    if (hud == null || !hud.IsValid())
        return;

    local levelText = "Level " + state.level.tostring() + "/" + TF2C_ArmsRace_GetMaxLevel().tostring();
    local colorText = TF2C_ArmsRace_GetTeamHudColorRGB(player.GetTeam()) + " 255";

    try { hud.__KeyValueFromString("message", levelText); } catch (e0) {}
    try { hud.__KeyValueFromString("color", colorText); } catch (e1) {}
    try { hud.__KeyValueFromString("color2", colorText); } catch (e2) {}
    try { EntFireByHandle(hud, "Display", "", 0.00, player, player); } catch (e3) {}
}

function TF2C_ArmsRace_ClearRankHUD(player)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    local hud = TF2C_ArmsRace_GetRankHudEntity(player);
    if (hud == null || !hud.IsValid())
        return;

    try { hud.__KeyValueFromString("message", " "); } catch (e0) {}
    try { EntFireByHandle(hud, "Display", "", 0.00, player, player); } catch (e1) {}
}

function TF2C_ArmsRace_ScheduleRankHUDRefresh(player)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    local entIdx = TF2C_ArmsRace_GetPlayerEntIndex(player);
    if (entIdx < 0)
        return;

    try
    {
        player.SetContextThink("TF2C_ArmsRace_RankHudA_" + entIdx, function()
        {
            try { TF2C_ArmsRace_UpdateRankHUD(player); } catch (e0) {}
            return null;
        }, 0.05);
    }
    catch (e1) {}

    try
    {
        player.SetContextThink("TF2C_ArmsRace_RankHudB_" + entIdx, function()
        {
            try { TF2C_ArmsRace_UpdateRankHUD(player); } catch (e2) {}
            return null;
        }, 0.18);
    }
    catch (e3) {}
}

function TF2C_ArmsRace_OnPlayerSpawn(params)
{
    if (!TF2C_ArmsRace_IsEnabled())
        return;
    if (params == null || !("userid" in params))
        return;

    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return;

    try { TF2C_ArmsRace_UpdateRankHUD(player); } catch (e1) {}
    TF2C_ArmsRace_ScheduleRankHUDRefresh(player);
}

function TF2C_ArmsRace_ChatAll(message)
{
    if (message == null || message == "")
        return;

    local player = null;
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!TF2C_ArmsRace_IsPlayablePlayer(player))
            continue;
        try { ClientPrint(player, 3, message); } catch (e0) {}
    }
}

function TF2C_ArmsRace_EnforceFallDamageState(player)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return

    try { TF2C_ArmsRace_RefreshFallDamageState(player); } catch (e0) {}

    try
    {
        if ("__Merc_RefreshFallDamageState" in getroottable())
            __Merc_RefreshFallDamageState(player);
    }
    catch (e1) {}
}

function TF2C_ArmsRace_AnnouncePromotion(player, level, weaponName)
{
    local teamColor = TF2C_ArmsRace_GetTeamColor(player.GetTeam());
    local maxLevel = TF2C_ArmsRace_GetMaxLevel();
    local message = teamColor + TF2C_ArmsRace_GetPlayerName(player)
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL + " has reached "
        + TF2C_ARMSRACE_CHAT_COLOR_GREEN + "Level " + level.tostring() + "/" + maxLevel.tostring() + ": " + weaponName
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL;
    TF2C_ArmsRace_ChatAll(message);
}

function TF2C_ArmsRace_AnnounceDemotion(player, level, weaponName)
{
    local teamColor = TF2C_ArmsRace_GetTeamColor(player.GetTeam());
    local maxLevel = TF2C_ArmsRace_GetMaxLevel();
    local message = teamColor + TF2C_ArmsRace_GetPlayerName(player)
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL + " was demoted to "
        + TF2C_ARMSRACE_CHAT_COLOR_RED + "Level " + level.tostring() + "/" + maxLevel.tostring() + ": " + weaponName
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL;
    TF2C_ArmsRace_ChatAll(message);
}

function TF2C_ArmsRace_AnnounceGoldenKnife(player)
{
    local teamColor = TF2C_ArmsRace_GetTeamColor(player.GetTeam());
    local message = teamColor + TF2C_ArmsRace_GetPlayerName(player)
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL + " has the "
        + TF2C_ARMSRACE_CHAT_COLOR_YELLOW + "Golden Knife"
        + TF2C_ARMSRACE_CHAT_COLOR_NORMAL + "! They only need one kill to win the game!";
    TF2C_ArmsRace_ChatAll(message);
}

function TF2C_ArmsRace_GetRoundWinEntity(teamNum)
{
    local targetName = "";
    if (teamNum == TF2C_ARMSRACE_TEAM_RED)
        targetName = "armsrace_red_win";
    else if (teamNum == TF2C_ARMSRACE_TEAM_BLU)
        targetName = "armsrace_blu_win";
    else if (teamNum == TF2C_ARMSRACE_TEAM_GRN)
        targetName = "armsrace_grn_win";
    else if (teamNum == TF2C_ARMSRACE_TEAM_YLW)
        targetName = "armsrace_ylw_win";

    if (targetName == "")
        return null;
    try { return Entities.FindByName(null, targetName); } catch (e0) { return null; }
}

function TF2C_ArmsRace_EndRound(teamNum)
{
    local winEnt = TF2C_ArmsRace_GetRoundWinEntity(teamNum);
    if (winEnt == null)
        return;
    try { EntFireByHandle(winEnt, "RoundWin", "", 0.15, null, null); } catch (e0) {}
}

function TF2C_ArmsRace_IsKnifeKill(params, attacker)
{
    local weaponName = "";
    try { weaponName = params.weapon.tolower(); } catch (e0) { weaponName = ""; }
    if (weaponName.find("knife") != null)
        return true;

    local weapon = null;
    try
    {
        if ("GetActiveWeapon" in attacker)
            weapon = attacker.GetActiveWeapon();
    }
    catch (e1) { weapon = null; }

    if (weapon == null && "NetProps" in getroottable())
    {
        try { weapon = NetProps.GetPropEntity(attacker, "m_hActiveWeapon"); } catch (e2) { weapon = null; }
    }
    if (weapon == null)
        return false;

    local defIndex = -1;
    try { defIndex = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e3) { defIndex = -1; }
    if (defIndex < 0)
    {
        try { defIndex = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e4) { defIndex = -1; }
    }
    if (defIndex == TF2C_ARMSRACE_ITEMDEF_KNIFE || defIndex == TF2C_ARMSRACE_ITEMDEF_GOLDEN_KNIFE)
        return true;

    local className = "";
    try { className = weapon.GetClassname().tolower(); } catch (e5) { className = ""; }
    return (className.find("knife") != null);
}

function TF2C_ArmsRace_ReapplyMeleeAttributes(player)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player) || !("NetProps" in getroottable()))
        return

    local melee = null
    try
    {
        for (local i = 0; i < 8; i++)
        {
            local held = null
            try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i) } catch (e0) { held = null }
            if (held == null)
                continue

            local slot = -2
            try { slot = held.GetSlot() } catch (e1) { slot = -2 }
            if (slot == 2)
            {
                melee = held
                break
            }
        }
    }
    catch (e2) { melee = null }

    if (melee == null)
        return

    try
    {
        if ("__Merc_ApplyOwnedMeleeAttributes" in getroottable())
            __Merc_ApplyOwnedMeleeAttributes(melee)
    }
    catch (e3) {}
}

function TF2C_ArmsRace_ScheduleMeleeAttributeRefresh(player, delay, suffix)
{
    if (!TF2C_ArmsRace_IsPlayablePlayer(player))
        return

    local entIdx = -1
    try { entIdx = player.entindex() } catch (e0) { entIdx = -1 }
    if (entIdx < 0)
        return

    try
    {
        player.SetContextThink("TF2C_ArmsRace_MeleeRefresh_" + entIdx + "_" + suffix, function()
        {
            try { TF2C_ArmsRace_ReapplyMeleeAttributes(player) } catch (e1) {}
            return null
        }, delay)
    }
    catch (e2) {}
}

function TF2C_ArmsRace_GiveLoadout(player)
{
    if (!TF2C_ArmsRace_IsEnabled() || !TF2C_ArmsRace_IsPlayablePlayer(player))
        return false;
    if (!TF2C_ArmsRace_EnsureWeaponSupport())
        return false;

    local state = TF2C_ArmsRace_GetState(player);
    if (state == null)
        return false;

    TF2C_ArmsRace_EnforceFallDamageState(player);

    try { __StripWeaponsAll(player); } catch (e0) {}
    TF2C_ArmsRace_ClearWeaponSlot(player, 0);
    TF2C_ArmsRace_ClearWeaponSlot(player, 1);
    TF2C_ArmsRace_ClearWeaponSlot(player, 2);
    try { if ("__RemoveWearablesAll" in getroottable()) __RemoveWearablesAll(player); } catch (e1) {}
    try { ClearPlayerReserveAmmo(player); } catch (e2) {}

    local meleeDef = TF2C_ArmsRace_IsGoldenKnifeLevel(state.level) ? TF2C_ARMSRACE_ITEMDEF_GOLDEN_KNIFE : TF2C_ARMSRACE_ITEMDEF_KNIFE;
    local melee = null;
    try { melee = GivePlayerWeapon(player, "tf_weapon_knife", meleeDef); } catch (e3) { melee = null; }
    try
    {
        if ("__Merc_ApplyOwnedMeleeAttributes" in getroottable())
            __Merc_ApplyOwnedMeleeAttributes(melee);
    }
    catch (e4) {}

    local currentWeapon = melee;
    if (!TF2C_ArmsRace_IsGoldenKnifeLevel(state.level))
    {
        local entry = TF2C_ArmsRace_GetLadderEntry(state.level);
        local weapon = null;
        try { weapon = GivePlayerWeapon(player, entry.className, entry.itemDef); } catch (e5) { weapon = null; }
        if (weapon != null)
        {
            try { ApplyWeaponAmmoDefaults(player, weapon, entry.className); } catch (e6) {}
            currentWeapon = weapon;
        }
    }

    try
    {
        if ("__DMRando_ScheduleAmmoFix" in getroottable())
        {
            __DMRando_ScheduleAmmoFix(player, 0.00);
            __DMRando_ScheduleAmmoFix(player, 0.05);
            __DMRando_ScheduleAmmoFix(player, 0.12);
        }
    }
    catch (e7) {}

    if (currentWeapon != null)
        TF2C_ArmsRace_EquipWeapon(player, currentWeapon);
    else if (melee != null)
        TF2C_ArmsRace_EquipWeapon(player, melee);

    TF2C_ArmsRace_ReapplyMeleeAttributes(player);
    TF2C_ArmsRace_ScheduleMeleeAttributeRefresh(player, 0.05, "a");
    TF2C_ArmsRace_ScheduleMeleeAttributeRefresh(player, 0.15, "b");
    TF2C_ArmsRace_ScheduleFallDamageRefresh(player);
    TF2C_ArmsRace_EnforceFallDamageState(player);
    try
    {
        if ("__Merc_ScheduleFallDamageRefresh" in getroottable())
        {
            __Merc_ScheduleFallDamageRefresh(player, 0.05, "armsrace_a");
            __Merc_ScheduleFallDamageRefresh(player, 0.15, "armsrace_b");
        }
    }
    catch (e11) {}
    try { TF2C_ArmsRace_UpdateRankHUD(player); } catch (e8) {}
    TF2C_ArmsRace_ScheduleRankHUDRefresh(player);
    try { TF2C_ArmsRace_SetGoldenKnifeGlowEnabled(player, TF2C_ArmsRace_IsGoldenKnifeLevel(state.level)); } catch (e9) {}

    return (currentWeapon != null || melee != null);
}

function TF2C_ArmsRace_PromotePlayer(player, viaKnife)
{
    local state = TF2C_ArmsRace_GetState(player);
    if (state == null)
        return false;

    local oldLevel = state.level;
    local maxLevel = TF2C_ArmsRace_GetMaxLevel();
    if (oldLevel >= maxLevel)
    {
        state.kills = 0;
        return false;
    }

    state.level = TF2C_ArmsRace_AdjustLevelForBot(player, oldLevel + 1, 1);
    state.kills = 0;

    if (TF2C_ArmsRace_IsPlayablePlayer(player) && player.IsAlive())
    {
        TF2C_ArmsRace_GiveLoadout(player);
        TF2C_ArmsRace_EnforceFallDamageState(player);
        TF2C_ArmsRace_ScheduleFallDamageRefresh(player);
    }
    else
        TF2C_ArmsRace_UpdateRankHUD(player);

    TF2C_ArmsRace_PlayClientSound(player, TF2C_ARMSRACE_SOUND_LEVEL_UP, TF2C_ARMSRACE_SOUND_LEVEL_UP_WAVE);
    TF2C_ArmsRace_PlayClientCommandSound(player, TF2C_ARMSRACE_SOUND_LEVEL_UP_COMMAND);
    TF2C_ArmsRace_ScheduleClientFeedbackSound(player, TF2C_ARMSRACE_SOUND_LEVEL_UP, TF2C_ARMSRACE_SOUND_LEVEL_UP_WAVE, TF2C_ARMSRACE_SOUND_LEVEL_UP_COMMAND, 0.10, "promote_a");
    TF2C_ArmsRace_ScheduleClientFeedbackSound(player, TF2C_ARMSRACE_SOUND_LEVEL_UP, TF2C_ARMSRACE_SOUND_LEVEL_UP_WAVE, TF2C_ARMSRACE_SOUND_LEVEL_UP_COMMAND, 0.35, "promote_b");

    local entry = TF2C_ArmsRace_GetLadderEntry(state.level);
    if (TF2C_ArmsRace_IsGoldenKnifeLevel(state.level))
    {
        TF2C_ArmsRace_AnnounceGoldenKnife(player);
        TF2C_ArmsRace_PlayGlobalSound(TF2C_ARMSRACE_SOUND_GOLDEN_KNIFE);
    }
    else
    {
        TF2C_ArmsRace_AnnouncePromotion(player, state.level, entry.name);
    }
    return true;
}

function TF2C_ArmsRace_DemotePlayer(player)
{
    local state = TF2C_ArmsRace_GetState(player);
    if (state == null)
        return false;

    local oldLevel = state.level;
    state.kills = 0;
    if (oldLevel <= 1)
        return false;

    state.level = TF2C_ArmsRace_AdjustLevelForBot(player, oldLevel - 1, -1);
    if (TF2C_ArmsRace_IsPlayablePlayer(player) && player.IsAlive())
    {
        TF2C_ArmsRace_EnforceFallDamageState(player);
        TF2C_ArmsRace_ScheduleFallDamageRefresh(player);
    }
    TF2C_ArmsRace_PlayClientSound(player, TF2C_ARMSRACE_SOUND_DEMOTED, TF2C_ARMSRACE_SOUND_DEMOTED_WAVE);
    TF2C_ArmsRace_PlayClientCommandSound(player, TF2C_ARMSRACE_SOUND_DEMOTED_COMMAND);
    TF2C_ArmsRace_ScheduleClientFeedbackSound(player, TF2C_ARMSRACE_SOUND_DEMOTED, TF2C_ARMSRACE_SOUND_DEMOTED_WAVE, TF2C_ARMSRACE_SOUND_DEMOTED_COMMAND, 0.10, "demote_a");
    TF2C_ArmsRace_ScheduleClientFeedbackSound(player, TF2C_ARMSRACE_SOUND_DEMOTED, TF2C_ARMSRACE_SOUND_DEMOTED_WAVE, TF2C_ARMSRACE_SOUND_DEMOTED_COMMAND, 0.35, "demote_b");
    TF2C_ArmsRace_UpdateRankHUD(player);
    TF2C_ArmsRace_SetGoldenKnifeGlowEnabled(player, false);

    local entry = TF2C_ArmsRace_GetLadderEntry(state.level);
    TF2C_ArmsRace_AnnounceDemotion(player, state.level, entry.name);
    return true;
}

function TF2C_ArmsRace_HandleAttackerKill(attacker, knifeKill)
{
    local state = TF2C_ArmsRace_GetState(attacker);
    if (state == null)
        return;

    if (knifeKill)
    {
        TF2C_ArmsRace_PromotePlayer(attacker, true);
        return;
    }

    if (TF2C_ArmsRace_IsGoldenKnifeLevel(state.level))
        return;

    state.kills += 1;
    if (state.kills >= 2)
        TF2C_ArmsRace_PromotePlayer(attacker, false);
}

function TF2C_ArmsRace_OnPlayerDeath(params)
{
    if (!TF2C_ArmsRace_IsEnabled())
        return;
    if (params == null || !("userid" in params))
        return;

    local victim = null;
    try { victim = GetPlayerFromUserID(params.userid); } catch (e0) { victim = null; }
    if (!TF2C_ArmsRace_IsPlayablePlayer(victim))
        return;

    local victimState = TF2C_ArmsRace_GetState(victim);
    if (victimState == null)
        return;

    try { TF2C_ArmsRace_ClearRankHUD(victim); } catch (eHud0) {}

    local attacker = null;
    try
    {
        if ("attacker" in params && params.attacker.tointeger() > 0)
            attacker = GetPlayerFromUserID(params.attacker);
    }
    catch (e1) { attacker = null; }

    if (!TF2C_ArmsRace_IsPlayablePlayer(attacker))
        return;
    if (attacker == victim)
        return;

    local attackerTeam = 0;
    local victimTeam = 0;
    try { attackerTeam = attacker.GetTeam(); } catch (e2) { attackerTeam = 0; }
    try { victimTeam = victim.GetTeam(); } catch (e3) { victimTeam = 0; }
    if (attackerTeam == victimTeam)
        return;

    local knifeKill = TF2C_ArmsRace_IsKnifeKill(params, attacker);
    local attackerState = TF2C_ArmsRace_GetState(attacker);
    if (attackerState == null)
        return;

    if (knifeKill && TF2C_ArmsRace_IsGoldenKnifeLevel(attackerState.level))
    {
        TF2C_ArmsRace_EndRound(attackerTeam);
        return;
    }

    if (knifeKill)
        TF2C_ArmsRace_DemotePlayer(victim);

    TF2C_ArmsRace_HandleAttackerKill(attacker, knifeKill);
}

function TF2C_ArmsRace_OnRoundStart(params)
{
    if (!TF2C_ArmsRace_IsEnabled())
        return;
    TF2C_ArmsRace_ResetAllState();
    TF2C_ArmsRace_ReapplyAllLoadouts();
    try
    {
        if (::TF2C_ArmsRace_Host != null && ::TF2C_ArmsRace_Host.IsValid())
        {
            EntFireByHandle(::TF2C_ArmsRace_Host, "RunScriptCode", "try{ TF2C_ArmsRace_ReapplyAllLoadouts(); }catch(e){}", 0.05, null, null);
            EntFireByHandle(::TF2C_ArmsRace_Host, "RunScriptCode", "try{ TF2C_ArmsRace_ReapplyAllLoadouts(); }catch(e){}", 0.15, null, null);
        }
    }
    catch (e0) {}
}

function TF2C_ArmsRace_OnPlayerDisconnect(params)
{
    if (params == null || !("userid" in params))
        return;
    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    if (player != null && player.IsValid())
    {
        TF2C_ArmsRace_ClearGoldenKnifeGlow(player);
        TF2C_ArmsRace_DestroyRankHudForEntIndex(TF2C_ArmsRace_GetPlayerEntIndex(player));
    }
    TF2C_ArmsRace_RemovePlayerStateByUserID(params.userid);
}

function TF2C_ArmsRace_Init(hostEnt = null)
{
    if (hostEnt != null)
        ::TF2C_ArmsRace_Host = hostEnt;

    try { PrecacheSound(TF2C_ARMSRACE_SOUND_DEMOTED_WAVE); } catch (e0) {}
    try { PrecacheSound(TF2C_ARMSRACE_SOUND_LEVEL_UP_WAVE); } catch (e1) {}
    try { PrecacheSound("mvm/mvm_warning.wav"); } catch (e2) {}
    try { PrecacheScriptSound(TF2C_ARMSRACE_SOUND_DEMOTED); } catch (e3) {}
    try { PrecacheScriptSound(TF2C_ARMSRACE_SOUND_LEVEL_UP); } catch (e4) {}
    try { PrecacheScriptSound(TF2C_ARMSRACE_SOUND_GOLDEN_KNIFE); } catch (e5) {}

    if (::TF2C_ArmsRace_EventsRegistered)
        return;
    if (!("ListenToGameEvent" in getroottable()))
        return;

    local ok = false;
    try
    {
        ListenToGameEvent("player_death", TF2C_ArmsRace_OnPlayerDeath, "");
        ListenToGameEvent("player_spawn", TF2C_ArmsRace_OnPlayerSpawn, "");
        ListenToGameEvent("teamplay_round_start", TF2C_ArmsRace_OnRoundStart, "");
        ListenToGameEvent("player_disconnect", TF2C_ArmsRace_OnPlayerDisconnect, "");
        ok = true;
    }
    catch (e4)
    {
        try
        {
            ListenToGameEvent("player_death", "TF2C_ArmsRace_OnPlayerDeath", "");
            ListenToGameEvent("player_spawn", "TF2C_ArmsRace_OnPlayerSpawn", "");
            ListenToGameEvent("teamplay_round_start", "TF2C_ArmsRace_OnRoundStart", "");
            ListenToGameEvent("player_disconnect", "TF2C_ArmsRace_OnPlayerDisconnect", "");
            ok = true;
        }
        catch (e6) { ok = false; }
    }

    ::TF2C_ArmsRace_EventsRegistered = ok;
}

getroottable()["TF2C_ArmsRace_IsEnabled"] <- TF2C_ArmsRace_IsEnabled;
getroottable()["TF2C_ArmsRace_GiveLoadout"] <- TF2C_ArmsRace_GiveLoadout;
getroottable()["TF2C_ArmsRace_OnPlayerDeath"] <- TF2C_ArmsRace_OnPlayerDeath;
getroottable()["TF2C_ArmsRace_OnPlayerSpawn"] <- TF2C_ArmsRace_OnPlayerSpawn;
getroottable()["TF2C_ArmsRace_OnRoundStart"] <- TF2C_ArmsRace_OnRoundStart;
getroottable()["TF2C_ArmsRace_OnPlayerDisconnect"] <- TF2C_ArmsRace_OnPlayerDisconnect;
getroottable()["TF2C_ArmsRace_ReapplyAllLoadouts"] <- TF2C_ArmsRace_ReapplyAllLoadouts;
getroottable()["TF2C_ArmsRace_Init"] <- TF2C_ArmsRace_Init;
