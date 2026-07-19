// tf2c_temp_powerups.nut
//
// Runtime crit/uber temporary powerups for Merc maps.
// Source map powerups are converted into info_target markers by the BSP patcher.

if (!IsServer())
    return;

const TF_COND_UBERCHARGED = 5;
const TF_COND_CRITBOOSTED = 11;

const MERC_TEMP_POWERUP_TOUCH_RADIUS = 48.0;
const MERC_TEMP_POWERUP_TOUCH_Z_TOLERANCE = 72.0;
const MERC_TEMP_POWERUP_ROTATE_SPEED = 180.0;
const MERC_TEMP_POWERUP_THINK_INTERVAL = 0.05;
const MERC_TEMP_POWERUP_DURATION = 30.0;
const MERC_TEMP_POWERUP_CRIT_RESPAWN = 60.0;
const MERC_TEMP_POWERUP_UBER_RESPAWN = 300.0;
const MERC_TEMP_POWERUP_COOLDOWN_ALPHA = 166;
const MERC_TEMP_POWERUP_DROP_OWNER_BLOCK = 1.0;
const MERC_TEMP_POWERUP_DROP_MIN_DURATION = 0.1;
const MERC_TEMP_POWERUP_GLOW_MODE = 0;
const MERC_TEMP_POWERUP_RESPAWN_SOUND = "MVM.TankStart";
const MERC_TEMP_POWERUP_GLOBAL_SOUNDLEVEL = 140;
const MERC_TEMP_POWERUP_LOCAL_SOUNDLEVEL = 70;
const MERC_TEMP_POWERUP_LOCAL_VOLUME = 0.65;

const MERC_TEMP_POWERUP_CRIT_MODEL_MANNPOWER = "models/pickups/pickup_powerup_crit.mdl";
const MERC_TEMP_POWERUP_UBER_MODEL_MANNPOWER = "models/pickups/pickup_powerup_uber.mdl";
const MERC_TEMP_POWERUP_CRIT_MODEL_BETA4 = "models/items/powerup_crit.mdl";
const MERC_TEMP_POWERUP_UBER_MODEL_BETA4 = "models/items/powerup_uber.mdl";
const MERC_TEMP_POWERUP_CRIT_PICKUP_SOUND = "items/powerup_pickup_crits.wav";
const MERC_TEMP_POWERUP_UBER_PICKUP_SOUND = "items/powerup_pickup_uber.wav";
const MERC_TEMP_POWERUP_CRIT_GLOW = "255 220 64 255";
const MERC_TEMP_POWERUP_UBER_GLOW = "255 220 64 255";

::MercTempPowerups_RuntimeHost <- null;
::MercTempPowerups_Entries <- {};
::MercTempPowerups_ThinkSerial <- 0;
::MercTempPowerups_ActiveTokens <- {};
::MercTempPowerups_ActiveEffects <- {};
::MercTempPowerups_PlayerStates <- {};
::MercTempPowerups_DroppedEntries <- {};
::MercTempPowerups_NextDropId <- 0;
::MercTempPowerups_EventsRegistered <- false;
::MercTempPowerups_CritPickupVoices <- [
    "Soldier.ActivateCharge01",
    "vo/customclass/mercenary/mercenary_berserk04.mp3",
    "Soldier.ActivateCharge03",
    "vo/customclass/mercenary/mercenary_cheers06.mp3"
];
::MercTempPowerups_SpentVoices <- [
    "vo/customclass/mercenary/mercenary_powerup_spent01.mp3",
    "vo/customclass/mercenary/mercenary_powerup_spent02.mp3",
    "vo/customclass/mercenary/mercenary_powerup_spent03.mp3"
];

function MercTempPowerups_GetConfiguredModel(powerType)
{
    local defaultModel = (powerType == "uber") ? MERC_TEMP_POWERUP_UBER_MODEL_BETA4 : MERC_TEMP_POWERUP_CRIT_MODEL_BETA4;
    local legacyModel = (powerType == "uber") ? MERC_TEMP_POWERUP_UBER_MODEL_MANNPOWER : MERC_TEMP_POWERUP_CRIT_MODEL_MANNPOWER;

    if ("__mercTempPowerupModelStyle" in getroottable())
    {
        local style = "";
        try { style = ::__mercTempPowerupModelStyle.tolower(); } catch (e1) { style = ""; }
        if (style == "mannpower" || style == "open_fortress" || style == "of")
        {
            ::__mercTempPowerupCritModel <- MERC_TEMP_POWERUP_CRIT_MODEL_MANNPOWER;
            ::__mercTempPowerupUberModel <- MERC_TEMP_POWERUP_UBER_MODEL_MANNPOWER;
            return legacyModel;
        }
    }

    local configured = null;
    if (powerType == "uber" && ("__mercTempPowerupUberModel" in getroottable()))
        configured = ::__mercTempPowerupUberModel;
    else if (powerType != "uber" && ("__mercTempPowerupCritModel" in getroottable()))
        configured = ::__mercTempPowerupCritModel;

    if (configured != null)
    {
        try
        {
            if (configured != "")
                return configured;
        }
        catch (e0) {}
    }

    return defaultModel;
}

function MercTempPowerups_GetWorldHost()
{
    local host = ::MercTempPowerups_RuntimeHost;
    if (host != null && host.IsValid())
        return host;

    try { host = self; } catch (e0) { host = null; }
    if (host == null)
        try { host = Entities.FindByClassname(null, "logic_script"); } catch (e1) { host = null; }
    if (host == null)
        try { host = Entities.FindByClassname(null, "worldspawn"); } catch (e2) { host = null; }
    return host;
}

function MercTempPowerups_IsPlayablePlayer(player)
{
    if (player == null || !player.IsValid())
        return false;
    try
    {
        if (!player.IsPlayer())
            return false;
    }
    catch (e0) { return false; }

    local team = 0;
    try { team = player.GetTeam(); } catch (e1) { team = 0; }
    if (team < 2)
        return false;

    try
    {
        if ("IsAlive" in player && !player.IsAlive())
            return false;
    }
    catch (e2) {}
    return true;
}

function MercTempPowerups_PickRandom(soundList)
{
    if (soundList == null || soundList.len() <= 0)
        return "";
    local idx = 0;
    try { idx = RandomInt(0, soundList.len() - 1); } catch (e0) { idx = 0; }
    if (idx < 0 || idx >= soundList.len())
        idx = 0;
    return soundList[idx];
}

function MercTempPowerups_GetPlayerScope(player)
{
    if (player == null || !player.IsValid())
        return null;
    try { player.ValidateScriptScope(); } catch (e0) {}
    local sc = null;
    try { sc = player.GetScriptScope(); } catch (e1) { sc = null; }
    return sc;
}

function MercTempPowerups_GetPlayerState(playerEntIndex, createIfMissing = false)
{
    if (playerEntIndex < 0)
        return null;
    local key = playerEntIndex.tostring();
    if (!(key in ::MercTempPowerups_PlayerStates))
    {
        if (!createIfMissing)
            return null;
        ::MercTempPowerups_PlayerStates[key] <- {
            critExpireAt = 0.0,
            uberExpireAt = 0.0
        };
    }
    return ::MercTempPowerups_PlayerStates[key];
}

function MercTempPowerups_SetPlayerEffectState(player, powerType, expireAt, token)
{
    local playerEntIndex = -1;
    try { playerEntIndex = player.entindex(); } catch (eEnt0) { playerEntIndex = -1; }
    local state = MercTempPowerups_GetPlayerState(playerEntIndex, true);
    if (state != null)
    {
        if (powerType == "uber")
            state.uberExpireAt = expireAt;
        else
            state.critExpireAt = expireAt;
    }

    local sc = MercTempPowerups_GetPlayerScope(player);
    if (sc == null)
        return;
    if (powerType == "uber")
    {
        sc.mercTempUberExpireAt <- expireAt;
        sc.mercTempUberToken <- token;
    }
    else
    {
        sc.mercTempCritExpireAt <- expireAt;
        sc.mercTempCritToken <- token;
    }
}

function MercTempPowerups_ClearPlayerEffectState(player, powerType)
{
    local playerEntIndex = -1;
    try { playerEntIndex = player.entindex(); } catch (eEnt0) { playerEntIndex = -1; }
    local state = MercTempPowerups_GetPlayerState(playerEntIndex, false);
    if (state != null)
    {
        if (powerType == "uber")
            state.uberExpireAt = 0.0;
        else
            state.critExpireAt = 0.0;
    }

    local sc = MercTempPowerups_GetPlayerScope(player);
    if (sc == null)
        return;
    if (powerType == "uber")
    {
        if ("mercTempUberExpireAt" in sc) delete sc.mercTempUberExpireAt;
        if ("mercTempUberToken" in sc) delete sc.mercTempUberToken;
    }
    else
    {
        if ("mercTempCritExpireAt" in sc) delete sc.mercTempCritExpireAt;
        if ("mercTempCritToken" in sc) delete sc.mercTempCritToken;
    }
}

function MercTempPowerups_GetPlayerEffectRemaining(player, powerType, now)
{
    local playerEntIndex = -1;
    try { playerEntIndex = player.entindex(); } catch (eEnt0) { playerEntIndex = -1; }
    local state = MercTempPowerups_GetPlayerState(playerEntIndex, false);
    if (state != null)
    {
        local stateExpireAt = 0.0;
        try { stateExpireAt = (powerType == "uber") ? state.uberExpireAt : state.critExpireAt; } catch (eState0) { stateExpireAt = 0.0; }
        if (stateExpireAt > 0.0)
            return stateExpireAt - now;
    }

    local sc = MercTempPowerups_GetPlayerScope(player);
    if (sc == null)
        return 0.0;

    local expireAt = 0.0;
    try
    {
        if (powerType == "uber")
        {
            if (!("mercTempUberExpireAt" in sc))
                return 0.0;
            expireAt = sc.mercTempUberExpireAt;
        }
        else
        {
            if (!("mercTempCritExpireAt" in sc))
                return 0.0;
            expireAt = sc.mercTempCritExpireAt;
        }
    }
    catch (e0) { return 0.0; }

    return expireAt - now;
}

function MercTempPowerups_GetTrackedEffectRemaining(playerEntIndex, powerType, now)
{
    local state = MercTempPowerups_GetPlayerState(playerEntIndex, false);
    if (state != null)
    {
        local stateExpireAt = 0.0;
        try { stateExpireAt = (powerType == "uber") ? state.uberExpireAt : state.critExpireAt; } catch (eState0) { stateExpireAt = 0.0; }
        if (stateExpireAt > 0.0)
            return stateExpireAt - now;
    }

    if (playerEntIndex < 0)
        return 0.0;

    local tokenKey = powerType + ":" + playerEntIndex.tostring();
    if (!(tokenKey in ::MercTempPowerups_ActiveEffects))
        return 0.0;

    local effect = ::MercTempPowerups_ActiveEffects[tokenKey];
    local expireAt = 0.0;
    try { expireAt = effect.expireAt; } catch (e0) { expireAt = 0.0; }
    return expireAt - now;
}

function MercTempPowerups_GetPlayerStateRemaining(playerEntIndex, powerType, now)
{
    local state = MercTempPowerups_GetPlayerState(playerEntIndex, false);
    if (state == null)
        return 0.0;

    local expireAt = 0.0;
    try { expireAt = (powerType == "uber") ? state.uberExpireAt : state.critExpireAt; } catch (e0) { expireAt = 0.0; }
    if (expireAt <= 0.0)
        return 0.0;
    return expireAt - now;
}

function MercTempPowerups_PlaySoundAtEntity(soundName, ent, channel = CHAN_STATIC, volume = 1.0, soundLevel = 60)
{
    if (soundName == null || soundName == "" || ent == null || !ent.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = ent,
        speakerentity = ent.entindex(),
        origin = ent.GetOrigin(),
        channel = channel,
        volume = volume,
        pitch = 100,
        soundlevel = soundLevel
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercTempPowerups_PlaySoundAtPlayer(soundName, player)
{
    if (soundName == null || soundName == "" || player == null || !player.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = player,
        speakerentity = player.entindex(),
        origin = player.GetOrigin(),
        channel = CHAN_VOICE,
        volume = MERC_TEMP_POWERUP_LOCAL_VOLUME,
        pitch = 100,
        soundlevel = MERC_TEMP_POWERUP_LOCAL_SOUNDLEVEL
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercTempPowerups_PlayBroadcastSound(soundName, originVec)
{
    if (soundName == null || soundName == "")
        return;

    local host = MercTempPowerups_GetWorldHost();
    if (host == null || !host.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = host,
        speakerentity = host.entindex(),
        origin = originVec,
        channel = CHAN_STATIC,
        volume = 1.0,
        pitch = 100,
        soundlevel = MERC_TEMP_POWERUP_GLOBAL_SOUNDLEVEL
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercTempPowerups_PlayPickupWorldSound(soundName, ent, soundLevel = 95)
{
    if (soundName == null || soundName == "")
        return;

    local anchor = ent;
    if (anchor == null || !anchor.IsValid())
        anchor = MercTempPowerups_GetWorldHost();
    if (anchor == null || !anchor.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = anchor,
        speakerentity = anchor.entindex(),
        origin = anchor.GetOrigin(),
        channel = CHAN_STATIC,
        volume = 1.0,
        pitch = 100,
        soundlevel = soundLevel
    };
    try { EmitSoundEx(params); return; } catch (e0) {}
    try { EmitSoundOn(soundName, anchor); } catch (e1) {}
}

function MercTempPowerups_PlayGlobalSound(soundName)
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
        if (!MercTempPowerups_IsPlayablePlayer(player))
            continue;
        try { EmitSoundOnClient(soundName, player); } catch (e1) {}
    }
}

function MercTempPowerups_ShowHudText(player, powerType, message)
{
    return;
}

function MercTempPowerups_ShowCenterHudText(player, message)
{
    return;
}

function MercTempPowerups_BuildHudMessages(player, now)
{
    return null;
}

function MercTempPowerups_GetHudEntity(player, powerType)
{
    return null;
}

function MercTempPowerups_ClearHud(player)
{
    return;
}

function MercTempPowerups_UpdateHud(now)
{
    return;
}

getroottable()["MercTempPowerups_HudTick"] <- function(playerEntIndex, token)
{
    return;
}

function MercTempPowerups_GetTypeConfig(powerType)
{
    if (powerType == "uber")
    {
        return {
            model = MercTempPowerups_GetConfiguredModel("uber"),
            skin = "1",
            respawnDelay = MERC_TEMP_POWERUP_UBER_RESPAWN,
            pickupSound = MERC_TEMP_POWERUP_UBER_PICKUP_SOUND,
            cond = TF_COND_UBERCHARGED
        };
    }

    return {
        model = MercTempPowerups_GetConfiguredModel("crit"),
        skin = "0",
        respawnDelay = MERC_TEMP_POWERUP_CRIT_RESPAWN,
        pickupSound = MERC_TEMP_POWERUP_CRIT_PICKUP_SOUND,
        cond = TF_COND_CRITBOOSTED
    };
}

function MercTempPowerups_SpawnProp(entry)
{
    local cfg = MercTempPowerups_GetTypeConfig(entry.powerType);
    local modelPath = cfg.model;
    if (("sourceModel" in entry) && entry.sourceModel != null && entry.sourceModel != "")
        modelPath = entry.sourceModel;

    local skinValue = cfg.skin;
    if (("sourceSkin" in entry) && entry.sourceSkin != null && entry.sourceSkin != "")
        skinValue = entry.sourceSkin;

    try { PrecacheModel(modelPath); } catch (ePrecache) {}
    local kv =
    {
        targetname = entry.propTargetname,
        model = modelPath,
        skin = skinValue,
        solid = "0",
        disableshadows = "0",
        disablereceiveshadows = "0",
        renderamt = "255",
        rendercolor = "255 255 255",
        rendermode = "1",
        angles = "0 0 0"
    };

    local ent = null;
    try { ent = SpawnEntityFromTable("prop_dynamic_override", kv); } catch (e0) { ent = null; }
    if (ent == null)
        try { ent = SpawnEntityFromTable("prop_dynamic", kv); } catch (e1) { ent = null; }
    if (ent == null)
        return null;

    try { ent.SetAbsOrigin(entry.origin); } catch (e2) {}
    try { EntFireByHandle(ent, "EnableDraw", "", 0.0, null, null); } catch (e3) {}
    return ent;
}

function MercTempPowerups_GetGlowColor(powerType)
{
    return powerType == "uber" ? MERC_TEMP_POWERUP_UBER_GLOW : MERC_TEMP_POWERUP_CRIT_GLOW;
}

function MercTempPowerups_SpawnGlow(entry, prop)
{
    if (prop == null || !prop.IsValid())
        return null;

    local targetName = "";
    try { targetName = prop.GetName(); } catch (e0) { targetName = ""; }
    if (targetName == "")
        return null;

    local kv =
    {
        targetname = entry.propTargetname + "_glow",
        target = targetName,
        Mode = MERC_TEMP_POWERUP_GLOW_MODE,
        GlowColor = MercTempPowerups_GetGlowColor(entry.powerType),
        StartDisabled = 1
    };

    local glow = null;
    try { glow = SpawnEntityFromTable("tf_glow", kv); } catch (e1) { glow = null; }
    return glow;
}

function MercTempPowerups_SetGlowEnabled(entry, enabled)
{
    if (entry == null)
        return;
    if ("glowEnabled" in entry && entry.glowEnabled == enabled)
        return;

    local glow = ("glow" in entry) ? entry.glow : null;
    if (glow == null || !glow.IsValid())
        return;

    try { EntFireByHandle(glow, enabled ? "Enable" : "Disable", "", 0.0, null, null); } catch (e0) {}
    entry.glowEnabled <- enabled;
}

function MercTempPowerups_SetGlowColor(entry, colorValue)
{
    if (entry == null)
        return;

    local glow = ("glow" in entry) ? entry.glow : null;
    if (glow == null || !glow.IsValid())
        return;

    if (colorValue == null || colorValue == "")
        colorValue = MercTempPowerups_GetGlowColor(entry.powerType);

    try { EntFireByHandle(glow, "SetGlowColor", colorValue, 0.0, null, null); } catch (e0) {}
}

function MercTempPowerups_SetPropVisibleState(prop, alpha)
{
    if (prop == null || !prop.IsValid())
        return;

    local clamped = alpha;
    if (clamped < 0) clamped = 0;
    if (clamped > 255) clamped = 255;

    try { EntFireByHandle(prop, "Alpha", clamped.tostring(), 0.0, null, null); } catch (e0) {}
    try { EntFireByHandle(prop, "Color", "255 255 255", 0.0, null, null); } catch (e1) {}
    try { prop.SetRenderAlpha(clamped); } catch (e2) {}
}

function MercTempPowerups_GetLinkedLightTargetname(markerTargetname)
{
    if (markerTargetname == null || markerTargetname == "")
        return "";

    local token = "__lt__";
    local splitAt = null;
    try { splitAt = markerTargetname.find(token); } catch (e0) { splitAt = null; }
    if (splitAt == null)
        return "";

    try { return markerTargetname.slice(splitAt + token.len()); } catch (e1) {}
    return "";
}

function MercTempPowerups_SetLinkedLightState(entry, enabled)
{
    if (entry == null)
        return;
    if (!("linkedLightTargetname" in entry))
        return;

    local targetname = entry.linkedLightTargetname;
    if (targetname == null || targetname == "")
        return;

    try { EntFire(targetname, enabled ? "TurnOn" : "TurnOff", "", 0.0, null); } catch (e0) {}
}

function MercTempPowerups_KillManaged()
{
    foreach (_name, entry in ::MercTempPowerups_Entries)
    {
        local prop = ("prop" in entry) ? entry.prop : null;
        try
        {
            if (prop != null && prop.IsValid())
                EntFireByHandle(prop, "Kill", "", 0.0, null, null);
        }
        catch (e0) {}
        local glow = ("glow" in entry) ? entry.glow : null;
        try
        {
            if (glow != null && glow.IsValid())
                EntFireByHandle(glow, "Kill", "", 0.0, null, null);
        }
        catch (e1) {}
    }
    ::MercTempPowerups_Entries.clear();

    foreach (_id, entry in ::MercTempPowerups_DroppedEntries)
    {
        local prop = ("prop" in entry) ? entry.prop : null;
        try
        {
            if (prop != null && prop.IsValid())
                EntFireByHandle(prop, "Kill", "", 0.0, null, null);
        }
        catch (e2) {}
        local glow = ("glow" in entry) ? entry.glow : null;
        try
        {
            if (glow != null && glow.IsValid())
                EntFireByHandle(glow, "Kill", "", 0.0, null, null);
        }
        catch (e3) {}
    }
    ::MercTempPowerups_DroppedEntries.clear();
}

function MercTempPowerups_DiscoverMarkers()
{
    MercTempPowerups_KillManaged();

    local marker = null;
    local markerIndex = 0;
    local now = 0.0;
    try { now = Time(); } catch (eNow) { now = 0.0; }
    while ((marker = Entities.FindByClassname(marker, "info_target")) != null)
    {
        local targetname = "";
        try { targetname = marker.GetName(); } catch (e0) { targetname = ""; }
        if (targetname.find("merc_powerup_marker_") != 0)
            continue;

        local powerType = "crit";
        try { powerType = marker.GetName().find("_uber_") != null ? "uber" : "crit"; } catch (e1) { powerType = "crit"; }
        local cfg = MercTempPowerups_GetTypeConfig(powerType);
        local origin = Vector(0, 0, 0);
        try { origin = marker.GetOrigin(); } catch (e2) {}
        local sourceModel = "";
        try { sourceModel = marker.GetModelName(); } catch (eModel0) { sourceModel = ""; }
        if (sourceModel == "" && ("NetProps" in getroottable()))
        {
            try { sourceModel = NetProps.GetPropString(marker, "m_ModelName"); } catch (eModel1) { sourceModel = ""; }
        }

        local sourceSkin = null;
        try
        {
            if ("GetSkin" in marker)
                sourceSkin = marker.GetSkin().tostring();
        }
        catch (eSkin0) { sourceSkin = null; }
        if (sourceSkin == null && ("NetProps" in getroottable()))
        {
            try { sourceSkin = NetProps.GetPropInt(marker, "m_nSkin").tostring(); } catch (eSkin1) { sourceSkin = null; }
        }

        local entry =
        {
            marker = marker,
            markerTargetname = targetname,
            linkedLightTargetname = MercTempPowerups_GetLinkedLightTargetname(targetname),
            propTargetname = format("__merc_runtime_powerup_prop_%d", markerIndex),
            prop = null,
            glow = null,
            glowEnabled = false,
            origin = origin,
            powerType = powerType,
            sourceModel = sourceModel,
            sourceSkin = sourceSkin,
            available = false,
            respawnAt = now + cfg.respawnDelay,
            yaw = 0.0,
            duration = MERC_TEMP_POWERUP_DURATION,
            respawnDelay = cfg.respawnDelay,
            touchRadiusSqr = MERC_TEMP_POWERUP_TOUCH_RADIUS * MERC_TEMP_POWERUP_TOUCH_RADIUS
        };

        entry.prop = MercTempPowerups_SpawnProp(entry);
        if (entry.prop != null)
        {
            entry.glow = MercTempPowerups_SpawnGlow(entry, entry.prop);
            MercTempPowerups_SetGlowEnabled(entry, false);
            MercTempPowerups_SetPropVisibleState(entry.prop, MERC_TEMP_POWERUP_COOLDOWN_ALPHA);
            MercTempPowerups_SetLinkedLightState(entry, false);
            ::MercTempPowerups_Entries[targetname] <- entry;
        }

        markerIndex++;
    }
}

function MercTempPowerups_ApplyCond(player, condId, duration)
{
    local didApply = false;
    try
    {
        if ("AddCond" in player)
        {
            player.AddCond(condId, duration);
            didApply = true;
        }
    }
    catch (e0) { didApply = false; }

    if (!didApply)
    {
        try
        {
            if ("AddCondEx" in player)
            {
                player.AddCondEx(condId, duration, null);
                didApply = true;
            }
        }
        catch (e1) { didApply = false; }
    }
    return didApply;
}

function MercTempPowerups_ClearPlayerTracking(playerEntIndex)
{
    if (playerEntIndex < 0)
        return;

    local stateKey = playerEntIndex.tostring();
    if (stateKey in ::MercTempPowerups_PlayerStates)
        delete ::MercTempPowerups_PlayerStates[stateKey];

    foreach (powerType in ["crit", "uber"])
    {
        local tokenKey = powerType + ":" + playerEntIndex.tostring();
        if (tokenKey in ::MercTempPowerups_ActiveTokens)
            delete ::MercTempPowerups_ActiveTokens[tokenKey];
        if (tokenKey in ::MercTempPowerups_ActiveEffects)
            delete ::MercTempPowerups_ActiveEffects[tokenKey];
    }
}

function MercTempPowerups_PopPlayerEffects(playerEntIndex)
{
    local results = [];
    if (playerEntIndex < 0)
        return results;

    foreach (powerType in ["crit", "uber"])
    {
        local tokenKey = powerType + ":" + playerEntIndex.tostring();
        local effect = null;
        if (tokenKey in ::MercTempPowerups_ActiveEffects)
        {
            effect = ::MercTempPowerups_ActiveEffects[tokenKey];
            delete ::MercTempPowerups_ActiveEffects[tokenKey];
        }
        if (tokenKey in ::MercTempPowerups_ActiveTokens)
            delete ::MercTempPowerups_ActiveTokens[tokenKey];
        if (effect != null)
            results.append(effect);
    }
    return results;
}

function MercTempPowerups_CollectDeathEffectDurations(player, playerEntIndex, now)
{
    local results = {
        crit = 0.0,
        uber = 0.0
    };

    foreach (powerType in ["crit", "uber"])
    {
        local stateRemaining = MercTempPowerups_GetPlayerStateRemaining(playerEntIndex, powerType, now);
        if (stateRemaining > results[powerType])
            results[powerType] = stateRemaining;

        local trackedRemaining = MercTempPowerups_GetTrackedEffectRemaining(playerEntIndex, powerType, now);
        if (trackedRemaining > results[powerType])
            results[powerType] = trackedRemaining;

        local tokenKey = powerType + ":" + playerEntIndex.tostring();
        if (tokenKey in ::MercTempPowerups_ActiveEffects)
        {
            local effect = ::MercTempPowerups_ActiveEffects[tokenKey];
            local expireAt = 0.0;
            try { expireAt = effect.expireAt; } catch (e0) { expireAt = 0.0; }
            local remaining = expireAt - now;
            if (remaining > results[powerType])
                results[powerType] = remaining;
        }

        local scopedRemaining = MercTempPowerups_GetPlayerEffectRemaining(player, powerType, now);
        if (scopedRemaining > results[powerType])
            results[powerType] = scopedRemaining;
    }

    return results;
}

function MercTempPowerups_GetDeathDropDurations(player, playerEntIndex, now)
{
    local results = {
        crit = 0.0,
        uber = 0.0
    };

    foreach (powerType in ["crit", "uber"])
    {
        local remaining = MercTempPowerups_GetPlayerStateRemaining(playerEntIndex, powerType, now);
        if (remaining > results[powerType])
            results[powerType] = remaining;

        local scopedRemaining = MercTempPowerups_GetPlayerEffectRemaining(player, powerType, now);
        if (scopedRemaining > results[powerType])
            results[powerType] = scopedRemaining;

        local trackedRemaining = MercTempPowerups_GetTrackedEffectRemaining(playerEntIndex, powerType, now);
        if (trackedRemaining > results[powerType])
            results[powerType] = trackedRemaining;
    }

    return results;
}

function MercTempPowerups_RemoveDroppedEntry(dropId)
{
    if (!(dropId in ::MercTempPowerups_DroppedEntries))
        return;

    local entry = ::MercTempPowerups_DroppedEntries[dropId];
    local prop = ("prop" in entry) ? entry.prop : null;
    try
    {
        if (prop != null && prop.IsValid())
            EntFireByHandle(prop, "Kill", "", 0.0, null, null);
    }
    catch (e0) {}

    local glow = ("glow" in entry) ? entry.glow : null;
    try
    {
        if (glow != null && glow.IsValid())
            EntFireByHandle(glow, "Kill", "", 0.0, null, null);
    }
    catch (e1) {}

    delete ::MercTempPowerups_DroppedEntries[dropId];
}

function MercTempPowerups_SpawnDroppedPowerup(powerType, origin, remainingDuration, ownerEntIndex)
{
    if (remainingDuration <= MERC_TEMP_POWERUP_DROP_MIN_DURATION)
        return;

    local now = 0.0;
    try { now = Time(); } catch (e0) { now = 0.0; }

    local dropId = ::MercTempPowerups_NextDropId;
    ::MercTempPowerups_NextDropId += 1;

    local entry =
    {
        marker = null,
        markerTargetname = format("__merc_runtime_powerup_drop_marker_%d", dropId),
        propTargetname = format("__merc_runtime_powerup_drop_prop_%d", dropId),
        prop = null,
        glow = null,
        glowEnabled = false,
        origin = origin + Vector(0, 0, 32),
        powerType = powerType,
        available = true,
        respawnAt = 0.0,
        yaw = 0.0,
        duration = remainingDuration,
        respawnDelay = 0.0,
        touchRadiusSqr = MERC_TEMP_POWERUP_TOUCH_RADIUS * MERC_TEMP_POWERUP_TOUCH_RADIUS,
        ownerEntIndex = ownerEntIndex,
        pickupBlockUntil = now + MERC_TEMP_POWERUP_DROP_OWNER_BLOCK,
        expiresAt = now + remainingDuration,
        isDropped = true,
    };

    entry.prop = ::MercTempPowerups_SpawnProp(entry);
    if (entry.prop == null)
        return;

    entry.glow = ::MercTempPowerups_SpawnGlow(entry, entry.prop);
    ::MercTempPowerups_SetPropVisibleState(entry.prop, 255);
    ::MercTempPowerups_SetGlowColor(entry, ::MercTempPowerups_GetGlowColor(entry.powerType));
    ::MercTempPowerups_SetGlowEnabled(entry, true);
    ::MercTempPowerups_DroppedEntries[dropId] <- entry;
}

getroottable()["MercTempPowerups_SpawnDroppedPowerupImmediate"] <- function(powerType, x, y, z, remainingDuration, ownerEntIndex)
{
    local origin = Vector(x, y, z);
    try { MercTempPowerups_SpawnDroppedPowerup(powerType, origin, remainingDuration, ownerEntIndex); } catch (e0) {}
}

getroottable()["MercTempPowerups_EndEffect"] <- function(playerEntIndex, powerType, token)
{
    if (!("EntIndexToHScript" in getroottable()))
        return;

    local tokenKey = powerType + ":" + playerEntIndex.tostring();
    if (!(tokenKey in ::MercTempPowerups_ActiveTokens))
        return;
    if (::MercTempPowerups_ActiveTokens[tokenKey] != token)
        return;
    delete ::MercTempPowerups_ActiveTokens[tokenKey];
    if (tokenKey in ::MercTempPowerups_ActiveEffects)
        delete ::MercTempPowerups_ActiveEffects[tokenKey];

    local player = null;
    try { player = EntIndexToHScript(playerEntIndex); } catch (e0) { player = null; }
    if (player == null || !player.IsValid())
        return;
    if (!MercTempPowerups_IsPlayablePlayer(player))
        return;
    MercTempPowerups_ClearPlayerEffectState(player, powerType);

    local condId = (powerType == "uber") ? TF_COND_UBERCHARGED : TF_COND_CRITBOOSTED;
    try { if ("RemoveCond" in player) player.RemoveCond(condId); } catch (e1) {}

    local spentVoice = MercTempPowerups_PickRandom(::MercTempPowerups_SpentVoices);
    MercTempPowerups_PlaySoundAtPlayer(spentVoice, player);
}

function MercTempPowerups_HandlePlayerDeath(player)
{
    if (player == null || !player.IsValid())
        return;

    local playerEntIndex = -1;
    try { playerEntIndex = player.entindex(); } catch (e1) { playerEntIndex = -1; }
    try { ::MercTempPowerups_ClearHud(player); } catch (eHud) {}
    local dropOrigin = Vector(0, 0, 0);
    try { dropOrigin = player.GetOrigin(); } catch (e2) {}
    local now = 0.0;
    try { now = Time(); } catch (e3) { now = 0.0; }

    local effectDurations = MercTempPowerups_GetDeathDropDurations(player, playerEntIndex, now);
    local host = MercTempPowerups_GetWorldHost();
    foreach (powerType, remainingDuration in effectDurations)
    {
        MercTempPowerups_ClearPlayerEffectState(player, powerType);
        if (remainingDuration <= MERC_TEMP_POWERUP_DROP_MIN_DURATION)
            continue;
        if (host != null && host.IsValid())
        {
            local code = format("try{ MercTempPowerups_SpawnDroppedPowerupImmediate(\"%s\", %f, %f, %f, %f, %d); }catch(e){}", powerType, dropOrigin.x, dropOrigin.y, dropOrigin.z, remainingDuration, playerEntIndex);
            try { EntFireByHandle(host, "RunScriptCode", code, 0.0, null, null); } catch (eDrop0) {}
        }
        else
            try { ::MercTempPowerups_SpawnDroppedPowerup(powerType, dropOrigin, remainingDuration, playerEntIndex); } catch (eDrop1) {}
    }
    MercTempPowerups_ClearPlayerTracking(playerEntIndex);
}

function MercTempPowerups_OnPlayerDeath(params)
{
    if (params == null || !("userid" in params))
        return;

    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    try { ::MercTempPowerups_HandlePlayerDeath(player); } catch (e1) {}
}

function MercTempPowerups_Grant(player, entry, durationOverride = null)
{
    if (!MercTempPowerups_IsPlayablePlayer(player))
        return false;

    local cfg = MercTempPowerups_GetTypeConfig(entry.powerType);
    local effectDuration = entry.duration;
    if (durationOverride != null)
        effectDuration = durationOverride;
    if (effectDuration <= MERC_TEMP_POWERUP_DROP_MIN_DURATION)
        effectDuration = MERC_TEMP_POWERUP_DROP_MIN_DURATION;

    if (!MercTempPowerups_ApplyCond(player, cfg.cond, effectDuration))
        return false;

    local playerEntIndex = -1;
    try { playerEntIndex = player.entindex(); } catch (e0) { playerEntIndex = -1; }
    if (playerEntIndex >= 0)
    {
        local tokenKey = entry.powerType + ":" + playerEntIndex.tostring();
        local token = 1;
        if (tokenKey in ::MercTempPowerups_ActiveTokens)
            token = ::MercTempPowerups_ActiveTokens[tokenKey] + 1;
        ::MercTempPowerups_ActiveTokens[tokenKey] <- token;
        local now = 0.0;
        try { now = Time(); } catch (eNow) { now = 0.0; }
        ::MercTempPowerups_ActiveEffects[tokenKey] <- {
            token = token,
            powerType = entry.powerType,
            expireAt = now + effectDuration,
            duration = effectDuration,
        };
        MercTempPowerups_SetPlayerEffectState(player, entry.powerType, now + effectDuration, token);

        local host = MercTempPowerups_GetWorldHost();
        if (host != null && host.IsValid())
        {
            local code = format("try{ MercTempPowerups_EndEffect(%d, \"%s\", %d); }catch(e){}", playerEntIndex, entry.powerType, token);
            try { EntFireByHandle(host, "RunScriptCode", code, effectDuration + 0.01, null, null); } catch (e1) {}
        }

    }

    local soundOrigin = entry.origin;
    try
    {
        if ("prop" in entry && entry.prop != null && entry.prop.IsValid())
            soundOrigin = entry.prop.GetOrigin();
    }
    catch (eSound0) {}

    local soundEnt = null;
    try
    {
        if ("prop" in entry && entry.prop != null && entry.prop.IsValid())
            soundEnt = entry.prop;
    }
    catch (eSound1) { soundEnt = null; }

    MercTempPowerups_PlayGlobalSound(cfg.pickupSound);
    MercTempPowerups_PlaySoundAtPlayer(MercTempPowerups_PickRandom(::MercTempPowerups_CritPickupVoices), player);

    return true;
}

function MercTempPowerups_Update()
{
    local now = 0.0;
    try { now = Time(); } catch (e0) { now = 0.0; }

    foreach (dropId, entry in clone ::MercTempPowerups_DroppedEntries)
    {
        local prop = ("prop" in entry) ? entry.prop : null;
        if (prop == null || !prop.IsValid())
        {
            MercTempPowerups_RemoveDroppedEntry(dropId);
            continue;
        }

        entry.yaw = (entry.yaw + (MERC_TEMP_POWERUP_ROTATE_SPEED * MERC_TEMP_POWERUP_THINK_INTERVAL)) % 360.0;
        try { prop.SetAbsAngles(QAngle(0, entry.yaw, 0)); } catch (eDrop0) {}

        if (now >= entry.expiresAt)
        {
            MercTempPowerups_RemoveDroppedEntry(dropId);
            continue;
        }

        MercTempPowerups_SetPropVisibleState(prop, 255);
        MercTempPowerups_SetGlowColor(entry, MercTempPowerups_GetGlowColor(entry.powerType));
        MercTempPowerups_SetGlowEnabled(entry, true);

        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!MercTempPowerups_IsPlayablePlayer(player))
                continue;

            local playerEntIndex = -1;
            try { playerEntIndex = player.entindex(); } catch (eDrop1) { playerEntIndex = -1; }
            if (playerEntIndex == entry.ownerEntIndex && now < entry.pickupBlockUntil)
                continue;

            local playerOrigin = Vector(0, 0, 0);
            try { playerOrigin = player.GetOrigin(); } catch (eDrop2) { continue; }
            local delta = playerOrigin - entry.origin;
            local horizontalDistSqr = (delta.x * delta.x) + (delta.y * delta.y);
            if (horizontalDistSqr > entry.touchRadiusSqr)
                continue;
            if (fabs(delta.z) > MERC_TEMP_POWERUP_TOUCH_Z_TOLERANCE)
                continue;

            local remainingDuration = entry.expiresAt - now;
            if (MercTempPowerups_Grant(player, entry, remainingDuration))
                MercTempPowerups_RemoveDroppedEntry(dropId);
            break;
        }
    }

    foreach (_name, entry in ::MercTempPowerups_Entries)
    {
        local prop = entry.prop;
        if (prop == null || !prop.IsValid())
        {
            entry.prop = MercTempPowerups_SpawnProp(entry);
            prop = entry.prop;
            if (prop == null)
                continue;
            entry.glow = MercTempPowerups_SpawnGlow(entry, prop);
            entry.glowEnabled = false;
        }

        local glow = ("glow" in entry) ? entry.glow : null;
        if (prop != null && prop.IsValid() && (glow == null || !glow.IsValid()))
        {
            entry.glow = MercTempPowerups_SpawnGlow(entry, prop);
            entry.glowEnabled = false;
        }

        entry.yaw = (entry.yaw + (MERC_TEMP_POWERUP_ROTATE_SPEED * MERC_TEMP_POWERUP_THINK_INTERVAL)) % 360.0;
        try { prop.SetAbsAngles(QAngle(0, entry.yaw, 0)); } catch (e2) {}

        if (!entry.available)
        {
            MercTempPowerups_SetGlowEnabled(entry, false);
            MercTempPowerups_SetPropVisibleState(prop, MERC_TEMP_POWERUP_COOLDOWN_ALPHA);
            if (now >= entry.respawnAt)
            {
                entry.available = true;
                MercTempPowerups_SetPropVisibleState(prop, 255);
                MercTempPowerups_SetGlowColor(entry, MercTempPowerups_GetGlowColor(entry.powerType));
                MercTempPowerups_SetGlowEnabled(entry, true);
                MercTempPowerups_SetLinkedLightState(entry, true);
                MercTempPowerups_PlayGlobalSound(MERC_TEMP_POWERUP_RESPAWN_SOUND);
            }
            else
            {
                continue;
            }
        }

        MercTempPowerups_SetPropVisibleState(prop, 255);
        MercTempPowerups_SetGlowColor(entry, MercTempPowerups_GetGlowColor(entry.powerType));
        MercTempPowerups_SetGlowEnabled(entry, true);

        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!MercTempPowerups_IsPlayablePlayer(player))
                continue;

            local playerOrigin = Vector(0, 0, 0);
            try { playerOrigin = player.GetOrigin(); } catch (e3) { continue; }
            local delta = playerOrigin - entry.origin;
            local horizontalDistSqr = (delta.x * delta.x) + (delta.y * delta.y);
            if (horizontalDistSqr > entry.touchRadiusSqr)
                continue;
            if (fabs(delta.z) > MERC_TEMP_POWERUP_TOUCH_Z_TOLERANCE)
                continue;

            if (MercTempPowerups_Grant(player, entry))
            {
                entry.available = false;
                entry.respawnAt = now + entry.respawnDelay;
                MercTempPowerups_SetGlowEnabled(entry, false);
                MercTempPowerups_SetPropVisibleState(prop, MERC_TEMP_POWERUP_COOLDOWN_ALPHA);
                MercTempPowerups_SetLinkedLightState(entry, false);
            }
            break;
        }
    }
}

getroottable()["MercTempPowerups_Tick"] <- function(hostEnt, serial)
{
    if (serial != ::MercTempPowerups_ThinkSerial)
        return;

    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        runtimeHost = ::MercTempPowerups_RuntimeHost;

    try { MercTempPowerups_Update(); } catch (e0) {}

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        local code = format("try{ MercTempPowerups_Tick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_TEMP_POWERUP_THINK_INTERVAL, null, null); } catch (e1) {}
    }
}

function MercTempPowerups_StartThink(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        return;

    ::MercTempPowerups_RuntimeHost = runtimeHost;
    ::MercTempPowerups_ThinkSerial += 1;
    local serial = ::MercTempPowerups_ThinkSerial;

    try
    {
        runtimeHost.SetContextThink("MercTempPowerupsThink", function()
        {
            try { MercTempPowerups_Update(); } catch (e0) {}
            return MERC_TEMP_POWERUP_THINK_INTERVAL;
        }, MERC_TEMP_POWERUP_THINK_INTERVAL);
    }
    catch (e1) {}

    local code = format("try{ MercTempPowerups_Tick(self, %d); }catch(e){}", serial);
    try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_TEMP_POWERUP_THINK_INTERVAL, null, null); } catch (e2) {}
}

getroottable()["MercTempPowerups_Init"] <- function(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null)
    {
        try { runtimeHost = Entities.FindByClassname(null, "logic_script"); } catch (e0) { runtimeHost = null; }
        if (runtimeHost == null)
            try { runtimeHost = Entities.FindByClassname(null, "worldspawn"); } catch (e1) { runtimeHost = null; }
    }

    ::MercTempPowerups_RuntimeHost = runtimeHost;

    try { PrecacheModel(MERC_TEMP_POWERUP_CRIT_MODEL_MANNPOWER); } catch (e2) {}
    try { PrecacheModel(MERC_TEMP_POWERUP_UBER_MODEL_MANNPOWER); } catch (e3) {}
    try { PrecacheModel(MERC_TEMP_POWERUP_CRIT_MODEL_BETA4); } catch (e3b) {}
    try { PrecacheModel(MERC_TEMP_POWERUP_UBER_MODEL_BETA4); } catch (e3c) {}
    try { PrecacheModel(MercTempPowerups_GetConfiguredModel("crit")); } catch (e3d) {}
    try { PrecacheModel(MercTempPowerups_GetConfiguredModel("uber")); } catch (e3e) {}
    try { PrecacheSound(MERC_TEMP_POWERUP_CRIT_PICKUP_SOUND); } catch (e4) {}
    try { PrecacheSound(MERC_TEMP_POWERUP_UBER_PICKUP_SOUND); } catch (e5) {}
    try { PrecacheSound(MERC_TEMP_POWERUP_RESPAWN_SOUND); } catch (e6) {}
    foreach (snd in ::MercTempPowerups_CritPickupVoices)
        try { PrecacheSound(snd); } catch (e7) {}
    foreach (snd in ::MercTempPowerups_SpentVoices)
        try { PrecacheSound(snd); } catch (e8) {}

    if (!::MercTempPowerups_EventsRegistered && ("ListenToGameEvent" in getroottable()))
    {
        local ok = false;
        try
        {
            ListenToGameEvent("player_death", MercTempPowerups_OnPlayerDeath, "");
            ok = true;
        }
        catch (eEvt0) {}
        if (!ok)
        {
            try
            {
                getroottable()["MercTempPowerups_OnPlayerDeath"] <- MercTempPowerups_OnPlayerDeath;
                ListenToGameEvent("player_death", "MercTempPowerups_OnPlayerDeath", "");
                ok = true;
            }
            catch (eEvt1) {}
        }
        if (ok)
            ::MercTempPowerups_EventsRegistered <- true;
    }

    try
    {
        if (runtimeHost != null && runtimeHost.IsValid())
        {
            EntFireByHandle(runtimeHost, "RunScriptCode", "MercTempPowerups_DiscoverMarkers();", 0.20, null, null);
            EntFireByHandle(runtimeHost, "RunScriptCode", "MercTempPowerups_StartThink(self);", 0.25, null, null);
            return;
        }
    }
    catch (e9) {}

    MercTempPowerups_DiscoverMarkers();
    MercTempPowerups_StartThink(runtimeHost);
}

getroottable()["MercTempPowerups_DiscoverMarkers"] <- MercTempPowerups_DiscoverMarkers;
getroottable()["MercTempPowerups_StartThink"] <- MercTempPowerups_StartThink;
getroottable()["MercTempPowerups_GetHudEntity"] <- MercTempPowerups_GetHudEntity;
getroottable()["MercTempPowerups_GetGlowColor"] <- MercTempPowerups_GetGlowColor;
getroottable()["MercTempPowerups_SpawnProp"] <- MercTempPowerups_SpawnProp;
getroottable()["MercTempPowerups_SpawnGlow"] <- MercTempPowerups_SpawnGlow;
getroottable()["MercTempPowerups_SetGlowEnabled"] <- MercTempPowerups_SetGlowEnabled;
getroottable()["MercTempPowerups_SetGlowColor"] <- MercTempPowerups_SetGlowColor;
getroottable()["MercTempPowerups_SetPropVisibleState"] <- MercTempPowerups_SetPropVisibleState;
getroottable()["MercTempPowerups_ClearHud"] <- MercTempPowerups_ClearHud;
getroottable()["MercTempPowerups_ShowHudText"] <- MercTempPowerups_ShowHudText;
getroottable()["MercTempPowerups_UpdateHud"] <- MercTempPowerups_UpdateHud;
getroottable()["MercTempPowerups_PopPlayerEffects"] <- MercTempPowerups_PopPlayerEffects;
getroottable()["MercTempPowerups_SpawnDroppedPowerup"] <- MercTempPowerups_SpawnDroppedPowerup;
getroottable()["MercTempPowerups_HandlePlayerDeath"] <- MercTempPowerups_HandlePlayerDeath;
getroottable()["MercTempPowerups_OnPlayerDeath"] <- MercTempPowerups_OnPlayerDeath;

MercTempPowerups_Init(null);
