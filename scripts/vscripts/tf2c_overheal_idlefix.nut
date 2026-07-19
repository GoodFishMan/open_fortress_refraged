// tf2c_overheal_idlefix.nut
//
// Responsibilities:
// - Preserve the existing compiled-pill overheal trigger fix.
// - Support script-driven Merc pill markers injected by the BSP patcher.
//
// Marker pills:
// - Source tiny healthkits are converted into info_target entities named merc_pill_marker_*.
// - At runtime we spawn a prop_dynamic pill model at each marker.
// - A lightweight proximity check handles touch, cooldown, draw toggling, and sounds.

const TF_CLASS_SOLDIER = 3;
const OVERHEAL_PILL_MODEL = "models/items/medkit_overheal.mdl";
const OVERHEAL_PILL_RESPAWN_SOUND = "BaseCombatWeapon.WeaponMaterialize";
const OVERHEAL_PILL_DEFAULT_HEAL = 10;
const OVERHEAL_PILL_RESPAWN_DELAY = 10.0;
const OVERHEAL_PILL_TOUCH_RADIUS = 48.0;
const OVERHEAL_PILL_TOUCH_Z_TOLERANCE = 72.0;
const OVERHEAL_PILL_TOUCH_SOUNDLEVEL = 30;
const OVERHEAL_PILL_TOUCH_VOLUME = 0.5;
const OVERHEAL_PILL_RESPAWN_SOUNDLEVEL = 38;
const OVERHEAL_PILL_RESPAWN_VOLUME = 0.5;
const OVERHEAL_PILL_ROTATE_SPEED = 180.0;
const OVERHEAL_PILL_THINK_INTERVAL = 0.05;
const OVERHEAL_PILL_MAX_HP = 300;

::OverhealIdleFix_BaseMaxHealth <- 150;
::OverhealIdleFix_FallbackAnnounced <- true;
::OverhealIdleFix_RuntimeHost <- null;
::OverhealIdleFix_PillEntries <- {};
::OverhealIdleFix_ThinkSerial <- 0;
::OverhealIdleFix_TouchSoundFiles <-
[
    "items/pills/pill_heal1.mp3",
    "items/pills/pill_heal2.mp3",
    "items/pills/pill_heal3.mp3",
    "items/pills/pill_heal4.mp3",
    "items/pills/pill_heal5.mp3",
    "items/pills/pill_heal6.mp3"
];

if (!("__CollectGameEventCallbacks" in getroottable()))
{
    getroottable()["__CollectGameEventCallbacks"] <- true;
}
else
{
    getroottable()["__CollectGameEventCallbacks"] = true;
}

function OverhealIdleFix_GetBaseMaxHealth()
{
    return 150;
}

function OverhealIdleFix_TryRecordBaselineFromPlayer(player)
{
    return;
}

function OverhealIdleFix_ScanForBaseline()
{
    return;
}

function OverhealIdleFix_GetTriggerDamage(triggerEnt)
{
    local dmg = 0.0;
    try
    {
        if ("GetDamage" in triggerEnt)
            dmg = triggerEnt.GetDamage().tofloat();
        else if ("NetProps" in getroottable())
            dmg = NetProps.GetPropFloat(triggerEnt, "m_flDamage");
    }
    catch (e)
    {
        dmg = 0.0;
    }
    return dmg;
}

getroottable()["OverhealIdleFix_OnTriggerHurt"] <- function()
{
    local rt = getroottable();
    local activatorEnt = ("activator" in rt) ? rt.activator : null;
    local callerEnt = ("caller" in rt) ? rt.caller : null;

    if (callerEnt == null)
    {
        try { callerEnt = self; } catch (e0) { callerEnt = null; }
    }

    if (activatorEnt == null || callerEnt == null) return;
    if (!activatorEnt.IsValid() || !callerEnt.IsValid()) return;

    local isPlayer = false;
    try { isPlayer = activatorEnt.IsPlayer(); } catch (e1) { isPlayer = false; }
    if (!isPlayer) return;

    local dmg = OverhealIdleFix_GetTriggerDamage(callerEnt);
    if (dmg != -20.0)
        return;

    local currentHp = 0;
    try { currentHp = activatorEnt.GetHealth().tointeger(); } catch (e2) { currentHp = 0; }

    if (currentHp >= OverhealIdleFix_GetBaseMaxHealth())
    {
        local newHp = currentHp + 5;
        if (newHp > OVERHEAL_PILL_MAX_HP) newHp = OVERHEAL_PILL_MAX_HP;

        local didSet = false;
        try
        {
            if ("SetHealth" in activatorEnt)
            {
                activatorEnt.SetHealth(newHp);
                didSet = true;
            }
        }
        catch (e3) { didSet = false; }

        if (!didSet && ("NetProps" in rt))
        {
            try { NetProps.SetPropInt(activatorEnt, "m_iHealth", newHp); } catch (e4) { }
        }
    }
}

function OverhealIdleFix_HookOverhealTriggers()
{
    local trig = null;
    while ((trig = Entities.FindByClassname(trig, "trigger_hurt")) != null)
    {
        if (OverhealIdleFix_GetTriggerDamage(trig) != -20.0)
            continue;

        try
        {
            EntFireByHandle(
                trig,
                "AddOutput",
                "OnHurtPlayer !self:RunScriptCode:OverhealIdleFix_OnTriggerHurt():0:-1",
                0.0,
                null,
                null
            );
        }
        catch (e1)
        {
            try
            {
                EntFireByHandle(
                    trig,
                    "AddOutput",
                    "OnStartTouch !self:RunScriptCode:OverhealIdleFix_OnTriggerHurt():0:-1",
                    0.0,
                    null,
                    null
                );
            }
            catch (e2) { }
        }
    }
}

function OverhealIdleFix_PlaySoundAtEntity(soundName, ent)
{
    if (ent == null || !ent.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = ent,
        channel = CHAN_STATIC,
        volume = OVERHEAL_PILL_RESPAWN_VOLUME,
        pitch = 100,
        soundlevel = OVERHEAL_PILL_RESPAWN_SOUNDLEVEL
    };

    try { EmitSoundEx(params); } catch (e0) { }
}

function OverhealIdleFix_PlayRawSoundAtEntity(soundPath, ent, soundLevel)
{
    if (ent == null || !ent.IsValid())
        return;

    local params =
    {
        sound_name = soundPath,
        entity = ent,
        channel = CHAN_STATIC,
        volume = OVERHEAL_PILL_TOUCH_VOLUME,
        pitch = 100,
        soundlevel = soundLevel
    };

    try { EmitSoundEx(params); } catch (e0) {}
}

function OverhealIdleFix_PlayRandomTouchSound(ent)
{
    if (ent == null || !ent.IsValid())
        return;

    local count = ::OverhealIdleFix_TouchSoundFiles.len();
    if (count <= 0)
        return;

    local idx = 0;
    try { idx = RandomInt(0, count - 1); } catch (e0) { idx = 0; }
    if (idx < 0 || idx >= count)
        idx = 0;

    OverhealIdleFix_PlayRawSoundAtEntity(::OverhealIdleFix_TouchSoundFiles[idx], ent, OVERHEAL_PILL_TOUCH_SOUNDLEVEL);
}

function OverhealIdleFix_IsPlayablePlayer(player)
{
    if (player == null || !player.IsValid())
        return false;

    local isPlayer = false;
    try { isPlayer = player.IsPlayer(); } catch (e0) { isPlayer = false; }
    if (!isPlayer)
        return false;

    local team = 0;
    try { team = player.GetTeam(); } catch (e1) { team = 0; }
    if (team < 2)
        return false;

    local hp = 0;
    try { hp = player.GetHealth().tointeger(); } catch (e2) { hp = 0; }
    return hp > 0;
}

function OverhealIdleFix_SpawnMarkerProp(entry)
{
    local kv =
    {
        targetname = entry.propTargetname,
        model = OVERHEAL_PILL_MODEL,
        modelscale = "1.0",
        solid = "0",
        disableshadows = "0",
        disablereceiveshadows = "0",
        renderamt = "255",
        rendercolor = "255 255 255",
        rendermode = "0",
        angles = "0 0 0"
    };

    local ent = null;
    try { ent = SpawnEntityFromTable("prop_dynamic_override", kv); } catch (e0) { ent = null; }
    if (ent == null)
    {
        try { ent = SpawnEntityFromTable("prop_dynamic", kv); } catch (e1) { ent = null; }
    }
    if (ent == null)
        return null;

    try { ent.SetAbsOrigin(entry.origin); } catch (e2) {}
    try { EntFireByHandle(ent, "EnableDraw", "", 0.0, null, null); } catch (e3) {}
    return ent;
}

function OverhealIdleFix_KillManagedPills()
{
    foreach (name, entry in ::OverhealIdleFix_PillEntries)
    {
        local prop = ("prop" in entry) ? entry.prop : null;
        try
        {
            if (prop != null && prop.IsValid())
                EntFireByHandle(prop, "Kill", "", 0.0, null, null);
        }
        catch (e0) {}
    }
    ::OverhealIdleFix_PillEntries.clear();

    local ent = null;
    while ((ent = Entities.FindByName(ent, "__merc_runtime_pill_*")) != null)
    {
        try { EntFireByHandle(ent, "Kill", "", 0.0, null, null); } catch (e1) {}
    }
}

function OverhealIdleFix_DiscoverMarkerPills()
{
    OverhealIdleFix_KillManagedPills();

    local marker = null;
    local markerIndex = 0;
    while ((marker = Entities.FindByClassname(marker, "info_target")) != null)
    {
        local targetname = "";
        try { targetname = marker.GetName(); } catch (e0) { targetname = ""; }
        if (targetname.find("merc_pill_marker_") != 0)
            continue;

        local origin = Vector(0, 0, 0);
        try { origin = marker.GetOrigin(); } catch (e1) {}

        local propTargetname = format("__merc_runtime_pill_prop_%d", markerIndex);
        local entry =
        {
            marker = marker,
            markerTargetname = targetname,
            propTargetname = propTargetname,
            prop = null,
            origin = origin,
            available = true,
            respawnAt = 0.0,
            yaw = 0.0,
            healAmount = OVERHEAL_PILL_DEFAULT_HEAL,
            touchRadiusSqr = OVERHEAL_PILL_TOUCH_RADIUS * OVERHEAL_PILL_TOUCH_RADIUS
        };

        entry.prop = OverhealIdleFix_SpawnMarkerProp(entry);
        if (entry.prop != null)
            ::OverhealIdleFix_PillEntries[targetname] <- entry;

        markerIndex++;
    }
}

function OverhealIdleFix_ApplyMarkerHeal(player, healAmount)
{
    if (!OverhealIdleFix_IsPlayablePlayer(player))
        return false;

    local currentHp = 0;
    try { currentHp = player.GetHealth().tointeger(); } catch (e0) { currentHp = 0; }
    local newHp = currentHp + healAmount;
    if (newHp > OVERHEAL_PILL_MAX_HP)
        newHp = OVERHEAL_PILL_MAX_HP;

    try
    {
        if ("SetHealth" in player)
        {
            player.SetHealth(newHp);
            return true;
        }
    }
    catch (e1) {}

    try
    {
        if ("NetProps" in getroottable())
        {
            NetProps.SetPropInt(player, "m_iHealth", newHp);
            return true;
        }
    }
    catch (e2) {}

    return false;
}

function OverhealIdleFix_UpdateMarkerPills()
{
    local now = 0.0;
    try { now = Time(); } catch (e0) { now = 0.0; }

    foreach (name, entry in ::OverhealIdleFix_PillEntries)
    {
        local prop = entry.prop;
        if (prop == null || !prop.IsValid())
        {
            entry.prop = OverhealIdleFix_SpawnMarkerProp(entry);
            prop = entry.prop;
            if (prop == null)
                continue;
        }

        if (!entry.available)
        {
            if (now >= entry.respawnAt)
            {
                entry.available = true;
                try { EntFireByHandle(prop, "EnableDraw", "", 0.0, null, null); } catch (e1) {}
                OverhealIdleFix_PlaySoundAtEntity(OVERHEAL_PILL_RESPAWN_SOUND, prop);
            }
            else
            {
                continue;
            }
        }

        entry.yaw = (entry.yaw + (OVERHEAL_PILL_ROTATE_SPEED * OVERHEAL_PILL_THINK_INTERVAL)) % 360.0;
        try { prop.SetAbsAngles(QAngle(0, entry.yaw, 0)); } catch (e2) {}

        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!OverhealIdleFix_IsPlayablePlayer(player))
                continue;

            local playerOrigin = Vector(0, 0, 0);
            try { playerOrigin = player.GetOrigin(); } catch (e3) { continue; }
            local delta = playerOrigin - entry.origin;
            local horizontalDistSqr = (delta.x * delta.x) + (delta.y * delta.y);
            if (horizontalDistSqr > entry.touchRadiusSqr)
                continue;
            if (fabs(delta.z) > OVERHEAL_PILL_TOUCH_Z_TOLERANCE)
                continue;

            if (OverhealIdleFix_ApplyMarkerHeal(player, entry.healAmount))
            {
                entry.available = false;
                entry.respawnAt = now + OVERHEAL_PILL_RESPAWN_DELAY;
                try { EntFireByHandle(prop, "DisableDraw", "", 0.0, null, null); } catch (e4) {}
                OverhealIdleFix_PlayRandomTouchSound(prop);
            }
            break;
        }
    }
}

getroottable()["OverhealIdleFix_Tick"] <- function(hostEnt, serial)
{
    if (serial != ::OverhealIdleFix_ThinkSerial)
        return;

    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        runtimeHost = ::OverhealIdleFix_RuntimeHost;

    try { OverhealIdleFix_UpdateMarkerPills(); } catch (e0) {}

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        local code = format("try{ OverhealIdleFix_Tick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, OVERHEAL_PILL_THINK_INTERVAL, null, null); } catch (e1) {}
    }
}

function OverhealIdleFix_StartMarkerThink(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        return;

    ::OverhealIdleFix_RuntimeHost = runtimeHost;
    ::OverhealIdleFix_ThinkSerial += 1;
    local serial = ::OverhealIdleFix_ThinkSerial;

    try
    {
        runtimeHost.SetContextThink("OverhealIdleFix_PillThink", function()
        {
            try { OverhealIdleFix_UpdateMarkerPills(); } catch (e0) {}
            return OVERHEAL_PILL_THINK_INTERVAL;
        }, OVERHEAL_PILL_THINK_INTERVAL);
    }
    catch (e1) {}

    local code = format("try{ OverhealIdleFix_Tick(self, %d); }catch(e){}", serial);
    try { EntFireByHandle(runtimeHost, "RunScriptCode", code, OVERHEAL_PILL_THINK_INTERVAL, null, null); } catch (e2) {}
}

getroottable()["OnGameEvent_player_spawn"] <- function(params)
{
    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    OverhealIdleFix_TryRecordBaselineFromPlayer(player);
}

getroottable()["OverhealIdleFix_Init"] <- function(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null)
    {
        try { runtimeHost = Entities.FindByClassname(null, "logic_vscript"); } catch (e0) { runtimeHost = null; }
        if (runtimeHost == null)
        {
            try { runtimeHost = Entities.FindByClassname(null, "worldspawn"); } catch (e1) { runtimeHost = null; }
        }
    }

    ::OverhealIdleFix_RuntimeHost = runtimeHost;

    try { PrecacheModel(OVERHEAL_PILL_MODEL); } catch (e2) {}
    foreach (soundPath in ::OverhealIdleFix_TouchSoundFiles)
    {
        try { PrecacheSound(soundPath); } catch (e3) {}
    }
    try { PrecacheSound(OVERHEAL_PILL_RESPAWN_SOUND); } catch (e4) {}

    try
    {
        if (runtimeHost != null && runtimeHost.IsValid())
        {
            EntFireByHandle(runtimeHost, "RunScriptCode", "OverhealIdleFix_HookOverhealTriggers();", 0.20, null, null);
            EntFireByHandle(runtimeHost, "RunScriptCode", "OverhealIdleFix_ScanForBaseline();", 0.25, null, null);
            EntFireByHandle(runtimeHost, "RunScriptCode", "OverhealIdleFix_DiscoverMarkerPills();", 0.30, null, null);
            EntFireByHandle(runtimeHost, "RunScriptCode", "OverhealIdleFix_StartMarkerThink(self);", 0.35, null, null);
            return;
        }
    }
    catch (e5) {}

    OverhealIdleFix_HookOverhealTriggers();
    OverhealIdleFix_ScanForBaseline();
    OverhealIdleFix_DiscoverMarkerPills();
    OverhealIdleFix_StartMarkerThink(runtimeHost);
}
