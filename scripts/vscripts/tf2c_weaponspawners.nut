// tf2c_weaponspawners.nut
//
// Runtime weapon pickup controller for Merc DM / Infection.
// The BSP patcher injects info_target markers named merc_weapon_marker_* with:
// - weapon_name
// - weapon_itemdef
// - weapon_class
// - weapon_model
// - respawndelay
// - touchradius

if (!IsServer())
    return;

if (!("__IncludeScriptOnce" in getroottable()))
{
    function __IncludeScriptOnce(scriptName)
    {
        if (!("__includedScripts" in getroottable()))
            ::__includedScripts <- {};
        if (scriptName in ::__includedScripts)
            return true;

        local rt = getroottable();
        local ok = false;
        try { ok = DoIncludeScript(scriptName, rt); } catch (e0) { ok = false; }
        if (ok)
            ::__includedScripts[scriptName] <- true;
        return ok;
    }
}

__IncludeScriptOnce("tf2c_weapondefs.nut");
__IncludeScriptOnce("tf2c_deathdrops.nut");

const MERC_WEAPON_MARKER_PREFIX = "merc_weapon_marker_";
const MERC_WEAPON_RESPAWN_DELAY = 10.0;
const MERC_WEAPON_RESPAWN_DELAY_STAY = 0.5;
const MERC_WEAPON_TOUCH_RADIUS = 48.0;
const MERC_WEAPON_TOUCH_Z_TOLERANCE = 72.0;
const MERC_WEAPON_ROTATE_SPEED = 180.0;
const MERC_WEAPON_THINK_INTERVAL = 0.05;
const MERC_WEAPON_PICKUP_SOUND = "AmmoPack.Touch";
const MERC_WEAPON_RESPAWN_SOUND = "BaseCombatWeapon.WeaponMaterialize";
const MERC_WEAPON_COOLDOWN_ALPHA = 186;
const MERC_WEAPON_GLOW_MODE = 1;
const MERC_WEAPON_GLOW_COLOR_TOUCH = "255 255 255 255";
const MERC_WEAPON_ENABLE_TOUCH_GLOW = false;
const MERC_WEAPON_USE_PROMPT = "Press F (+use) to switch";
const MERC_WEAPON_USE_PROMPT_INTERVAL = 4.0;
const MERC_WEAPON_USE_PROMPT_SOUND = "Hud.Hint";
const MERC_WEAPON_AUTOGRAB_CHANCE = 0.18;
const MERC_WEAPON_AUTOGRAB_SOUNDLEVEL = 70;
const MERC_WEAPON_AUTOGRAB_VOLUME = 0.65;
const MERC_WEAPON_ORIGIN_MATCH_RADIUS_SQR = 64.0;
const IN_USE = 32;

::MercWeaponSpawner_ModelOverrides <-
{
    [2001] = "models/weapons/w_models/w_nailgun.mdl",
    [2002] = "models/weapons/w_models/w_rpg.mdl",
    [2006] = "models/weapons/w_models/w_grenade_mirv_demo.mdl",
    [2013] = "models/weapons/w_models/w_twinbarrel.mdl",
    [2014] = "models/weapons/w_models/w_aagun.mdl",
    [2018] = "models/weapons/w_models/w_nader.mdl",
    [2020] = "models/weapons/w_models/w_speedcane.mdl",
    [2021] = "models/weapons/w_models/w_cyclops.mdl"
};

::MercWeaponSpawner_RuntimeHost <- null;
::MercWeaponSpawner_Entries <- {};
::MercWeaponSpawner_ThinkSerial <- 0;
::MercWeaponSpawner_LastUsePromptTime <- {};
::MercWeaponSpawner_PromptEntities <- {};
::MercWeaponSpawner_AutograbVoices <- [
    "vo/customclass/mercenary/mercenary_autograbbedintelligence01.mp3",
    "vo/customclass/mercenary/mercenary_autograbbedintelligence02.mp3",
    "vo/customclass/mercenary/mercenary_autograbbedintelligence03.mp3"
];
::MercWeaponSpawner_TwinBarrelPickupVoices <- [
    "vo/customclass/mercenary/mercenary_pickup_supershotgun02.mp3",
    "vo/customclass/mercenary/mercenary_positivevocalization02.mp3"
];
::MercWeaponSpawner_AAGunPickupVoices <- [
    "vo/customclass/mercenary/mercenary_specialcompleted999.mp3"
];
::MercWeaponSpawner_FriendlyNamesByItemDef <- {
    [5] = "Fists",
    [6] = "Crowbar",
    [7] = "Lead Pipe",
    [9] = "Shotgun",
    [10] = "Shotgun",
    [16] = "Sten Gun",
    [18] = "Rocket Launcher",
    [19] = "Grenade Launcher",
    [35] = "Flare Gun",
    [171] = "Knife",
    [197] = "Wrench",
    [2001] = "Nailgun",
    [2002] = "RPG",
    [2006] = "MIRV",
    [2013] = "Super Shotgun",
    [2014] = "Anti Aircraft Gun",
    [2018] = "Rejuvenator",
    [2021] = "Cyclops"
};
::MercWeaponSpawner_FriendlyNamesByClass <- {
    ["tf_weapon_shotgun"] = "Shotgun",
    ["tf_weapon_shotgun_primary"] = "Shotgun",
    ["tf_weapon_shotgun_soldier"] = "Shotgun",
    ["tf_weapon_shotgun_hwg"] = "Shotgun",
    ["tf_weapon_shotgun_pyro"] = "Shotgun",
    ["tf_weapon_rocketlauncher"] = "Rocket Launcher",
    ["tf_weapon_grenadelauncher"] = "Grenade Launcher",
    ["tf_weapon_smg"] = "Sten Gun",
    ["tf_weapon_sniperrifle"] = "Sniper Rifle",
    ["tf_weapon_flaregun"] = "Flare Gun",
    ["tf_weapon_pistol"] = "Pistol",
    ["tf_weapon_bottle"] = "Coffee Pot",
    ["tf_weapon_knife"] = "Knife",
    ["tf_weapon_shovel"] = "Crowbar",
    ["tf_weapon_wrench"] = "Lead Pipe",
    ["tf_weapon_syringegun_medic"] = "Syringe Gun",
    ["tf_weapon_minigun"] = "Minigun",
    ["tf_weapon_grenade_mirv"] = "MIRV",
    ["tf2c_weapon_doubleshotgun"] = "Super Shotgun",
    ["tf2c_weapon_nailgun"] = "Nailgun",
    ["tf2c_weapon_aagun"] = "Anti Aircraft Gun",
    ["tf2c_weapon_rpg"] = "RPG",
    ["tf2c_weapon_nader"] = "Rejuvenator",
    ["tf2c_weapon_cyclops"] = "Cyclops",
    ["tf2c_weapon_heallauncher"] = "Rejuvenator",
    ["tf_weapon_flamethrower"] = "Flame Thrower"
};

function MercWeaponSpawner_WeaponStayEnabled()
{
    if ("__Merc_WeaponStayEnabled" in getroottable())
    {
        try { return __Merc_WeaponStayEnabled(); } catch (e0) {}
    }
    return false;
}

function MercWeaponSpawner_RequireUseToSwitchEnabled()
{
    if ("__Merc_WeaponSpawnersUseEnabled" in getroottable())
    {
        try { return __Merc_WeaponSpawnersUseEnabled(); } catch (e0) {}
    }
    return false;
}

if (!("GivePlayerWeapon" in getroottable()))
{
    function GivePlayerWeapon(player, classname, itemDefIndex)
    {
        if (player == null || !player.IsValid())
            return null;

        local weapon = null;
        try { weapon = Entities.CreateByClassname(classname); } catch (e0) { weapon = null; }
        if (weapon == null)
            return null;

        if ("NetProps" in getroottable())
        {
            try { NetProps.SetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", itemDefIndex); } catch (e1) {}
            try { NetProps.SetPropBool(weapon, "m_AttributeManager.m_Item.m_bInitialized", true); } catch (e2) {}
            try { NetProps.SetPropBool(weapon, "m_bValidatedAttachedEntity", true); } catch (e3) {}
        }

        try { weapon.SetTeam(player.GetTeam()); } catch (e4) {}
        try { weapon.DispatchSpawn(); } catch (e5) {}
        try { player.Weapon_Equip(weapon); } catch (e6) {}

        local equippedOk = false;
        if ("NetProps" in getroottable())
        {
            for (local i = 0; i < 8; i++)
            {
                local held = null;
                try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e7) { held = null; }
                if (held == weapon)
                {
                    equippedOk = true;
                    break;
                }
            }
        }

        if (!equippedOk)
        {
            try { weapon.Destroy(); } catch (e8) { try { weapon.Kill(); } catch (e9) {} }
            return null;
        }

        if ("NetProps" in getroottable())
        {
            local newSlot = -1;
            try { newSlot = weapon.GetSlot(); } catch (e10) { newSlot = -1; }
            if (newSlot != -1)
            {
                for (local i = 0; i < 8; i++)
                {
                    local held = null;
                    try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e11) { held = null; }
                    if (held == null || held == weapon)
                        continue;

                    local heldSlot = -2;
                    try { heldSlot = held.GetSlot(); } catch (e12) { heldSlot = -2; }
                    if (heldSlot != newSlot)
                        continue;

                    try { held.Destroy(); } catch (e13) { try { held.Kill(); } catch (e14) {} }
                    try { NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); } catch (e15) {}
                }
            }
        }

        return weapon;
    }
}

function MercWeaponSpawner_IsPlayablePlayer(player)
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
    return team >= 2;
}

function MercWeaponSpawner_ParseFloat(value, fallback)
{
    try { return value.tofloat(); } catch (e0) {}
    try { return value.tostring().tofloat(); } catch (e1) {}
    return fallback;
}

function MercWeaponSpawner_ParseInt(value, fallback)
{
    try { return value.tointeger(); } catch (e0) {}
    try { return value.tostring().tointeger(); } catch (e1) {}
    return fallback;
}

function MercWeaponSpawner_IsUsePressed(player)
{
    if (!("NetProps" in getroottable()))
        return false;
    local buttons = 0;
    try { buttons = NetProps.GetPropInt(player, "m_nButtons"); } catch (e0) { buttons = 0; }
    return ((buttons & IN_USE) != 0);
}

function MercWeaponSpawner_IsBotPlayer(player)
{
    if (player == null || !player.IsValid())
        return false;

    if ("__Merc_IsBotPlayer" in getroottable())
    {
        try { return __Merc_IsBotPlayer(player); } catch (e0) {}
    }

    try
    {
        if ("IsFakeClient" in player)
            return player.IsFakeClient();
    }
    catch (e1) {}

    if ("NetProps" in getroottable())
    {
        try
        {
            if (NetProps.GetPropBool(player, "m_bIsABot"))
                return true;
        }
        catch (e2) {}
    }

    return false;
}

function MercWeaponSpawner_GetWeaponDef(itemDefId)
{
    if ("GetWeaponDefById" in getroottable())
    {
        try { return GetWeaponDefById(itemDefId); } catch (e0) {}
    }

    if ("g_WeaponDefs" in getroottable())
    {
        foreach (def in g_WeaponDefs)
        {
            try
            {
                if (def.id == itemDefId)
                    return def;
            }
            catch (e1) {}
        }
    }
    return null;
}

function MercWeaponSpawner_GetFriendlyWeaponName(itemDefId, weaponClass = null, fallbackName = "")
{
    if (itemDefId in ::MercWeaponSpawner_FriendlyNamesByItemDef)
        return ::MercWeaponSpawner_FriendlyNamesByItemDef[itemDefId];

    if (weaponClass != null && weaponClass in ::MercWeaponSpawner_FriendlyNamesByClass)
        return ::MercWeaponSpawner_FriendlyNamesByClass[weaponClass];

    if (fallbackName != null && fallbackName != "")
    {
        if (fallbackName == "Twin Barrel")
            return "Super Shotgun";
        if (fallbackName == "SMG" || fallbackName == "TF_WEAPON_SMG")
            return "Sten Gun";
        if (fallbackName == "TF_WEAPON_SHOVEL")
            return "Crowbar";
        if (fallbackName == "TF_WEAPON_BOTTLE")
            return "Coffee Pot";
        if (fallbackName == "TF_WEAPON_WRENCH")
            return "Lead Pipe";
        return fallbackName;
    }

    if (weaponClass != null && weaponClass != "")
        return weaponClass;
    return "Weapon";
}

function MercWeaponSpawner_ResolveWorldModel(itemDefId, def)
{
    if (def != null)
    {
        try
        {
            if ("modelWorld" in def && def.modelWorld != null && def.modelWorld != "")
                return def.modelWorld;
        }
        catch (e0) {}
    }

    if (itemDefId in ::MercWeaponSpawner_ModelOverrides)
        return ::MercWeaponSpawner_ModelOverrides[itemDefId];

    return "";
}

function MercWeaponSpawner_ResolveGiveClass(def)
{
    if (def == null)
        return null;

    local className = null;
    try { if ("itemClass" in def) className = def.itemClass; } catch (e0) { className = null; }
    if (className == null)
        return null;

    if (className == "tf_weapon_shotgun")
    {
        local itemSlot = null;
        try { if ("itemSlot" in def) itemSlot = def.itemSlot; } catch (e1) { itemSlot = null; }
        if (itemSlot == "primary")
            return "tf_weapon_shotgun_primary";
        return "tf_weapon_shotgun_soldier";
    }

    return className;
}

function MercWeaponSpawner_ResolveSlotIndex(def, weaponClass)
{
    if (def != null)
    {
        local itemSlot = null;
        try { if ("itemSlot" in def) itemSlot = def.itemSlot; } catch (e0) { itemSlot = null; }
        if (itemSlot == "primary")
            return 0;
        if (itemSlot == "secondary")
            return 1;
        if (itemSlot == "melee")
            return 2;
        if (itemSlot == "building")
            return 3;
        if (itemSlot == "pda")
            return 4;
    }

    if (weaponClass == null)
        return -1;
    if (weaponClass.find("shotgun") != null || weaponClass.find("grenadelauncher") != null || weaponClass.find("rocketlauncher") != null || weaponClass.find("sniperrifle") != null)
        return 0;
    if (weaponClass.find("smg") != null || weaponClass.find("flaregun") != null || weaponClass.find("syringegun") != null || weaponClass.find("pistol") != null)
        return 1;
    if (weaponClass.find("shovel") != null || weaponClass.find("bat") != null || weaponClass.find("knife") != null || weaponClass.find("wrench") != null || weaponClass.find("bottle") != null)
        return 2;
    return -1;
}

function MercWeaponSpawner_PlaySound(soundName, ent)
{
    if (ent == null || !ent.IsValid())
        return;

    local params =
    {
        sound_name = soundName,
        entity = ent,
        channel = CHAN_STATIC,
        volume = 1.0,
        pitch = 100,
        soundlevel = 60
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercWeaponSpawner_PlaySoundAtPlayer(soundName, player)
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
        volume = MERC_WEAPON_AUTOGRAB_VOLUME,
        pitch = 100,
        soundlevel = MERC_WEAPON_AUTOGRAB_SOUNDLEVEL
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercWeaponSpawner_MaybePlayAutograbVoice(player, weaponItemDef = -1)
{
    if (player == null || !player.IsValid())
        return;

    local roll = 1.0;
    try { roll = RandomFloat(0.0, 1.0); } catch (e0) { roll = 1.0; }
    if (roll > MERC_WEAPON_AUTOGRAB_CHANCE)
        return;

    local voicePool = ::MercWeaponSpawner_AutograbVoices;
    if (weaponItemDef == 2013)
        voicePool = ::MercWeaponSpawner_TwinBarrelPickupVoices;
    else if (weaponItemDef == 2014)
        voicePool = ::MercWeaponSpawner_AAGunPickupVoices;

    local idx = 0;
    try { idx = RandomInt(0, voicePool.len() - 1); } catch (e1) { idx = 0; }
    if (idx < 0 || idx >= voicePool.len())
        idx = 0;
    MercWeaponSpawner_PlaySoundAtPlayer(voicePool[idx], player);
}

function MercWeaponSpawner_SetPropVisibleState(prop, alpha)
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

function MercWeaponSpawner_ParseOriginText(originText)
{
    if (originText == null)
        return null;

    local parts = split(originText, " ");
    if (parts.len() != 3)
        return null;

    local x = 0.0;
    local y = 0.0;
    local z = 0.0;
    try { x = parts[0].tofloat(); } catch (e0) { return null; }
    try { y = parts[1].tofloat(); } catch (e1) { return null; }
    try { z = parts[2].tofloat(); } catch (e2) { return null; }
    return Vector(x, y, z);
}

function MercWeaponSpawner_FindEntryByOriginText(originText)
{
    local targetOrigin = MercWeaponSpawner_ParseOriginText(originText);
    if (targetOrigin == null)
        return null;

    local bestEntry = null;
    local bestDistSqr = MERC_WEAPON_ORIGIN_MATCH_RADIUS_SQR;
    foreach (name, entry in ::MercWeaponSpawner_Entries)
    {
        if (!("origin" in entry))
            continue;
        local delta = entry.origin - targetOrigin;
        local distSqr = (delta.x * delta.x) + (delta.y * delta.y) + (delta.z * delta.z);
        if (distSqr <= bestDistSqr)
        {
            bestDistSqr = distSqr;
            bestEntry = entry;
        }
    }
    return bestEntry;
}

function MercWeaponSpawner_FindEntryByCoords(x, y, z)
{
    local targetOrigin = null;
    try { targetOrigin = Vector(x.tofloat(), y.tofloat(), z.tofloat()); } catch (e0) { targetOrigin = null; }
    if (targetOrigin == null)
        return null;

    local bestEntry = null;
    local bestDistSqr = MERC_WEAPON_ORIGIN_MATCH_RADIUS_SQR;
    foreach (name, entry in ::MercWeaponSpawner_Entries)
    {
        if (!("origin" in entry))
            continue;
        local delta = entry.origin - targetOrigin;
        local distSqr = (delta.x * delta.x) + (delta.y * delta.y) + (delta.z * delta.z);
        if (distSqr <= bestDistSqr)
        {
            bestDistSqr = distSqr;
            bestEntry = entry;
        }
    }
    return bestEntry;
}

function MercWeaponSpawner_SetEntryEnabled(entry, enabled)
{
    if (entry == null)
        return false;

    entry.enabled <- enabled ? true : false;
    if (!entry.enabled)
    {
        entry.respawnAt <- 0.0;
        entry.respawnWarnAt <- -1.0;
        entry.respawnWarned <- false;
        if ("prop" in entry)
            MercWeaponSpawner_SetPropVisibleState(entry.prop, 0);
        MercWeaponSpawner_SetGlowEnabled(entry, false);
        return true;
    }

    entry.respawnAt <- 0.0;
    entry.respawnWarnAt <- -1.0;
    entry.respawnWarned <- false;
    if ("prop" in entry)
        MercWeaponSpawner_SetPropVisibleState(entry.prop, 255);
    MercWeaponSpawner_SetGlowEnabled(entry, false);
    return true;
}

function MercWeaponSpawner_EnableByOrigin(originText)
{
    local entry = MercWeaponSpawner_FindEntryByOriginText(originText);
    if (entry == null)
        return false;
    return MercWeaponSpawner_SetEntryEnabled(entry, true);
}

function MercWeaponSpawner_DisableByOrigin(originText)
{
    local entry = MercWeaponSpawner_FindEntryByOriginText(originText);
    if (entry == null)
        return false;
    return MercWeaponSpawner_SetEntryEnabled(entry, false);
}

function MercWeaponSpawner_EnableByCoords(x, y, z)
{
    local entry = MercWeaponSpawner_FindEntryByCoords(x, y, z);
    if (entry == null)
        return false;
    return MercWeaponSpawner_SetEntryEnabled(entry, true);
}

function MercWeaponSpawner_DisableByCoords(x, y, z)
{
    local entry = MercWeaponSpawner_FindEntryByCoords(x, y, z);
    if (entry == null)
        return false;
    return MercWeaponSpawner_SetEntryEnabled(entry, false);
}

function MercWeaponSpawner_ResetByCoords(x, y, z, delaySeconds)
{
    local fx = 0.0;
    local fy = 0.0;
    local fz = 0.0;
    local delayValue = 0.0;
    try { fx = x.tofloat(); } catch (e0) {}
    try { fy = y.tofloat(); } catch (e1) {}
    try { fz = z.tofloat(); } catch (e2) {}
    try { delayValue = delaySeconds.tofloat(); } catch (e3) {}

    try { MercWeaponSpawner_DisableByCoords(fx, fy, fz); } catch (e4) {}
    if (delayValue <= 0.0)
    {
        try { MercWeaponSpawner_EnableByCoords(fx, fy, fz); } catch (e5) {}
        return true;
    }

    local code = format("try{MercWeaponSpawner_EnableByCoords(%f,%f,%f);}catch(e){}", fx, fy, fz);
    if ("EntFire" in getroottable())
    {
        try { EntFire("logic_vscript", "RunScriptCode", code, delayValue, null); } catch (e6) {}
        return true;
    }
    if (::MercWeaponSpawner_RuntimeHost != null && ::MercWeaponSpawner_RuntimeHost.IsValid())
    {
        try { EntFireByHandle(::MercWeaponSpawner_RuntimeHost, "RunScriptCode", code, delayValue, null, null); } catch (e7) {}
        return true;
    }

    return false;
}

function MercWeaponSpawner_HandleWarheadGIBPickup()
{
    // Preserve dm_warhead's aperture sequence while also controlling the Merc AA marker.
    try { MercWeaponSpawner_DisableByCoords(0, 0, 48); } catch (e0) {}
    if ("EntFire" in getroottable())
    {
        try { EntFire("relay_apertureCtrl", "Trigger", "", 146.0, null); } catch (e1) {}
        try { EntFire("logic_vscript", "RunScriptCode", "try{MercWeaponSpawner_EnableByCoords(0,0,48);}catch(e){}", 180.0, null); } catch (e2) {}
    }
}

function MercWeaponSpawner_PlayerHasWeapon(player, itemDefId, weaponClass)
{
    if ("MercDeathDrops_PlayerHasWeapon" in getroottable())
    {
        try { return MercDeathDrops_PlayerHasWeapon(player, itemDefId, weaponClass); } catch (e0) {}
    }

    if (player == null || !player.IsValid())
        return false;
    if (!("NetProps" in getroottable()))
        return false;

    for (local i = 0; i < 8; i++)
    {
        local weapon = null;
        try { weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e1) { weapon = null; }
        if (weapon == null)
            continue;

        local heldItemDefId = -1;
        try { heldItemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e2) { heldItemDefId = -1; }
        if (heldItemDefId < 0)
            try { heldItemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e3) { heldItemDefId = -1; }
        if (heldItemDefId >= 0 && heldItemDefId == itemDefId)
            return true;

        local className = null;
        try { className = weapon.GetClassname(); } catch (e4) { className = null; }
        if (weaponClass != null && weaponClass != "" && className == weaponClass)
            return true;
    }

    return false;
}

function MercWeaponSpawner_GetWeaponInSlot(player, slotIndex)
{
    if (player == null || !player.IsValid() || slotIndex < 0)
        return null;

    local weapon = null;
    try { if ("GetPlayerWeaponSlot" in player) weapon = player.GetPlayerWeaponSlot(slotIndex); } catch (e0) { weapon = null; }
    if (weapon == null)
        try { if ("GetWeaponBySlot" in player) weapon = player.GetWeaponBySlot(slotIndex); } catch (e1) { weapon = null; }
    if (weapon != null)
        return weapon;

    if ("NetProps" in getroottable())
    {
        for (local i = 0; i < 8; i++)
        {
            local held = null;
            try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e2) { held = null; }
            if (held == null)
                continue;

            local heldSlot = -2;
            try { heldSlot = held.GetSlot(); } catch (e3) { heldSlot = -2; }
            if (heldSlot == slotIndex)
                return held;
        }
    }

    return null;
}

function MercWeaponSpawner_IsPistolWeapon(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return false;

    local className = null;
    try { className = weapon.GetClassname(); } catch (e0) { className = null; }
    if (className == "tf_weapon_pistol")
        return true;

    local itemDefId = -1;
    try { itemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e1) { itemDefId = -1; }
    if (itemDefId < 0)
        try { itemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e2) { itemDefId = -1; }
    return (itemDefId == 22 || itemDefId == 23);
}

function MercWeaponSpawner_RequiresUseToPickup(player, entry, occupiedSlotWeapon)
{
    if (occupiedSlotWeapon == null)
        return false;
    if (MercWeaponSpawner_IsBotPlayer(player))
        return false;
    if (!MercWeaponSpawner_RequireUseToSwitchEnabled())
        return false;

    local occupiedItemDefId = -1;
    try { occupiedItemDefId = NetProps.GetPropInt(occupiedSlotWeapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (eItem0) { occupiedItemDefId = -1; }
    if (occupiedItemDefId < 0)
        try { occupiedItemDefId = NetProps.GetPropInt(occupiedSlotWeapon, "m_iItemDefinitionIndex"); } catch (eItem1) { occupiedItemDefId = -1; }
    if (occupiedItemDefId >= 0 && occupiedItemDefId == entry.weaponItemDef)
        return false;

    local slotIndex = ("weaponSlotIndex" in entry) ? entry.weaponSlotIndex : -1;

    if (slotIndex == 1 && "__Merc_WeaponSpawnersReplacePistolEnabled" in getroottable())
    {
        local allowPistolReplace = false;
        try { allowPistolReplace = __Merc_WeaponSpawnersReplacePistolEnabled(); } catch (e0) { allowPistolReplace = false; }
        if (allowPistolReplace && MercWeaponSpawner_IsPistolWeapon(occupiedSlotWeapon))
            return false;
    }

    return true;
}

function MercWeaponSpawner_ShowUsePrompt(player)
{
    if (player == null || !player.IsValid())
        return;

    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    if (entIdx < 0)
        return;

    local now = 0.0;
    try { now = Time(); } catch (e1) { now = 0.0; }
    local last = -999.0;
    if (entIdx in ::MercWeaponSpawner_LastUsePromptTime)
        last = ::MercWeaponSpawner_LastUsePromptTime[entIdx];
    if ((now - last) < MERC_WEAPON_USE_PROMPT_INTERVAL)
        return;

    ::MercWeaponSpawner_LastUsePromptTime[entIdx] <- now;
    try { ClientPrint(player, 4, MERC_WEAPON_USE_PROMPT); } catch (e2) {}
    try { EmitSoundOn(MERC_WEAPON_USE_PROMPT_SOUND, player); } catch (e3) { try { MercWeaponSpawner_PlaySound(MERC_WEAPON_USE_PROMPT_SOUND, player); } catch (e4) {} }
}

function MercWeaponSpawner_ApplyMercMeleePenalty(weapon, itemDefId, weaponClass)
{
    if (weapon == null || !weapon.IsValid())
        return;

    local applyPenalty = false;
    if (itemDefId == 1 || itemDefId == 7)
        applyPenalty = true;
    if (weaponClass == "tf_weapon_bottle" || weaponClass == "tf_weapon_wrench")
        applyPenalty = true;
    if (!applyPenalty)
        return;

    try
    {
        if ("AddAttribute" in weapon)
        {
            weapon.AddAttribute("max health additive penalty", -50, -1);
            if ("__Merc_ShouldGrantNoFallDamage" in getroottable() && __Merc_ShouldGrantNoFallDamage())
                weapon.AddAttribute("cancel falling damage", 1, -1);
        }
    }
    catch (e0) {}
}

function MercWeaponSpawner_GetWeaponDisplayNameFromDef(def, fallbackName = "Weapon")
{
    local itemDefId = -1;
    local weaponClass = null;
    try { if ("id" in def) itemDefId = def.id; } catch (eId) { itemDefId = -1; }
    try { if ("itemClass" in def) weaponClass = MercWeaponSpawner_ResolveGiveClass(def); } catch (eClass) { weaponClass = null; }
    if (def != null)
    {
        try
        {
            if ("name" in def && def.name != null && def.name != "")
                return MercWeaponSpawner_GetFriendlyWeaponName(itemDefId, weaponClass, def.name);
        }
        catch (e0) {}
    }
    return MercWeaponSpawner_GetFriendlyWeaponName(itemDefId, weaponClass, fallbackName);
}

function MercWeaponSpawner_GetWeaponDisplayNameFromEntity(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return "weapon";

    local itemDefId = -1;
    try { itemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e0) { itemDefId = -1; }
    if (itemDefId < 0)
        try { itemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e1) { itemDefId = -1; }

    if (itemDefId >= 0)
    {
        local def = MercWeaponSpawner_GetWeaponDef(itemDefId);
        local resolved = MercWeaponSpawner_GetWeaponDisplayNameFromDef(def, "");
        if (resolved != "")
            return resolved;
    }

    local className = "weapon";
    try { className = weapon.GetClassname(); } catch (e2) { className = "weapon"; }
    return MercWeaponSpawner_GetFriendlyWeaponName(itemDefId, className, className);
}

function MercWeaponSpawner_BuildUsePrompt(player, entry, occupiedSlotWeapon)
{
    local pickupName = "weapon";
    try
    {
        if ("weaponName" in entry && entry.weaponName != null && entry.weaponName != "")
            pickupName = entry.weaponName;
    }
    catch (e0) {}

    local currentName = MercWeaponSpawner_GetWeaponDisplayNameFromEntity(occupiedSlotWeapon);
    return format("Press F (+use) to swap %s for %s", currentName, pickupName);
}

function MercWeaponSpawner_ShowSwapPrompt(player, entry, occupiedSlotWeapon)
{
    if (player == null || !player.IsValid())
        return;

    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    if (entIdx < 0)
        return;

    local now = 0.0;
    try { now = Time(); } catch (e1) { now = 0.0; }
    local last = -999.0;
    if (entIdx in ::MercWeaponSpawner_LastUsePromptTime)
        last = ::MercWeaponSpawner_LastUsePromptTime[entIdx];
    if ((now - last) < MERC_WEAPON_USE_PROMPT_INTERVAL)
        return;

    ::MercWeaponSpawner_LastUsePromptTime[entIdx] <- now;
    local prompt = MERC_WEAPON_USE_PROMPT;
    try { prompt = MercWeaponSpawner_BuildUsePrompt(player, entry, occupiedSlotWeapon); } catch (e2) { prompt = MERC_WEAPON_USE_PROMPT; }
    local promptEnt = null;
    if (entIdx in ::MercWeaponSpawner_PromptEntities)
        promptEnt = ::MercWeaponSpawner_PromptEntities[entIdx];
    if (promptEnt == null || !promptEnt.IsValid())
    {
        try
        {
            promptEnt = SpawnEntityFromTable("game_text",
            {
                targetname = format("__merc_weapon_prompt_%d", entIdx),
                channel = "4",
                x = "-1",
                y = "0.78",
                effect = "0",
                color = "255 255 255 255",
                color2 = "255 255 255 255",
                fadein = "0.0",
                fadeout = "0.0",
                holdtime = "4.2",
                fxtime = "0.0",
                spawnflags = "0",
                message = ""
            });
        }
        catch (ePrompt0) { promptEnt = null; }
        if (promptEnt != null)
            ::MercWeaponSpawner_PromptEntities[entIdx] <- promptEnt;
    }
    if (promptEnt != null && promptEnt.IsValid())
    {
        try { promptEnt.__KeyValueFromString("message", prompt); } catch (e3) {}
        try { EntFireByHandle(promptEnt, "Display", "", 0.0, player, player); } catch (e4) {}
    }
    else
        try { ClientPrint(player, 4, prompt); } catch (e5) {}
    try { EmitSoundOn(MERC_WEAPON_USE_PROMPT_SOUND, player); } catch (e6) { try { MercWeaponSpawner_PlaySound(MERC_WEAPON_USE_PROMPT_SOUND, player); } catch (e7) {} }
}

function MercWeaponSpawner_ClearUsePromptCooldown(player)
{
    if (player == null || !player.IsValid())
        return;

    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    if (entIdx < 0)
        return;

    if (entIdx in ::MercWeaponSpawner_LastUsePromptTime)
        delete ::MercWeaponSpawner_LastUsePromptTime[entIdx];

    local promptEnt = null;
    if (entIdx in ::MercWeaponSpawner_PromptEntities)
        promptEnt = ::MercWeaponSpawner_PromptEntities[entIdx];
    if (promptEnt != null && promptEnt.IsValid())
    {
        try { promptEnt.__KeyValueFromString("message", " "); } catch (e1) {}
        try { EntFireByHandle(promptEnt, "Display", "", 0.0, player, player); } catch (e2) {}
    }
}

function MercWeaponSpawner_SpawnProp(entry)
{
    local kv =
    {
        targetname = entry.name + "_prop",
        origin = entry.originText,
        angles = entry.anglesText,
        model = entry.weaponModel,
        solid = 0,
        disableshadows = 1,
        rendermode = 1,
        renderamt = 255,
        rendercolor = "255 255 255"
    };

    local ent = null;
    try { ent = SpawnEntityFromTable("prop_dynamic_override", kv); } catch (e0) { ent = null; }
    if (ent == null)
        try { ent = SpawnEntityFromTable("prop_dynamic", kv); } catch (e1) { ent = null; }
    return ent;
}

function MercWeaponSpawner_SpawnGlow(entry, prop)
{
    if (prop == null || !prop.IsValid())
        return null;

    local targetName = "";
    try { targetName = prop.GetName(); } catch (e0) { targetName = ""; }
    if (targetName == "")
        return null;

    local kv =
    {
        targetname = entry.name + "_glow",
        target = targetName,
        Mode = MERC_WEAPON_GLOW_MODE,
        GlowColor = MERC_WEAPON_GLOW_COLOR_TOUCH,
        StartDisabled = 1
    };

    local glow = null;
    try { glow = SpawnEntityFromTable("tf_glow", kv); } catch (e1) { glow = null; }
    return glow;
}

function MercWeaponSpawner_SetGlowColor(entry, colorValue)
{
    if (entry == null)
        return;
    if ("glowColor" in entry && entry.glowColor == colorValue)
        return;

    local glow = ("glow" in entry) ? entry.glow : null;
    if (glow == null || !glow.IsValid())
        return;

    try { EntFireByHandle(glow, "SetGlowColor", colorValue, 0.0, null, null); } catch (e0) {}
    entry.glowColor <- colorValue;
}

function MercWeaponSpawner_SetGlowEnabled(entry, enabled)
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

function MercWeaponSpawner_KillManaged()
{
    foreach (name, entry in ::MercWeaponSpawner_Entries)
    {
        if ("glow" in entry)
        {
            local glow = entry.glow;
            if (glow != null)
            {
                try { if (glow.IsValid()) glow.Kill(); } catch (eGlow0) {}
            }
        }
        if (!("prop" in entry))
            continue;
        local prop = entry.prop;
        if (prop != null)
        {
            try { if (prop.IsValid()) prop.Kill(); } catch (e0) {}
        }
    }
    ::MercWeaponSpawner_Entries.clear();
}

function MercWeaponSpawner_DiscoverMarkers()
{
    MercWeaponSpawner_KillManaged();

    local marker = null;
    while ((marker = Entities.FindByClassname(marker, "info_target")) != null)
    {
        local targetname = "";
        try { targetname = marker.GetName(); } catch (e0) { targetname = ""; }
        if (targetname == null || targetname.find(MERC_WEAPON_MARKER_PREFIX) != 0)
            continue;

        local weaponModel = "";
        local weaponClass = "";
        local weaponName = "";
        local weaponItemDef = -1;
        local respawnDelay = MercWeaponSpawner_WeaponStayEnabled() ? MERC_WEAPON_RESPAWN_DELAY_STAY : MERC_WEAPON_RESPAWN_DELAY;
        local touchRadius = MERC_WEAPON_TOUCH_RADIUS;
        local encoded = targetname.slice(MERC_WEAPON_MARKER_PREFIX.len());
        local separator = encoded.find("_");
        if (separator == null)
            continue;
        weaponItemDef = MercWeaponSpawner_ParseInt(encoded.slice(0, separator), -1);
        if (weaponItemDef < 0)
            continue;

        local def = MercWeaponSpawner_GetWeaponDef(weaponItemDef);
        if (def == null)
            continue;

        try { weaponClass = MercWeaponSpawner_ResolveGiveClass(def); } catch (e1) { weaponClass = null; }
        try { if ("name" in def) weaponName = def.name; } catch (e2) {}
        weaponModel = MercWeaponSpawner_ResolveWorldModel(weaponItemDef, def);

        if (weaponClass == null || weaponClass == "")
            continue;

        local origin = marker.GetOrigin();
        local angles = marker.GetAngles();
        local startsDisabled = (targetname.tolower().find("_disabled") != null);
        local entry =
        {
            name = targetname,
            marker = marker,
            origin = origin,
            originText = format("%f %f %f", origin.x, origin.y, origin.z),
            anglesText = format("%f %f %f", angles.x, angles.y, angles.z),
            pickupRelay = targetname + "_pickup",
            respawnWarnRelay = targetname + "_respawnwarn",
            respawnWarnAt = -1.0,
            respawnWarned = false,
            weaponName = MercWeaponSpawner_GetFriendlyWeaponName(weaponItemDef, weaponClass, weaponName),
            weaponClass = weaponClass,
            weaponItemDef = weaponItemDef,
            weaponSlotIndex = MercWeaponSpawner_ResolveSlotIndex(def, weaponClass),
            weaponModel = weaponModel,
            respawnDelay = respawnDelay,
            respawnAt = 0.0,
            touchRadiusSqr = touchRadius * touchRadius,
            yaw = angles.y,
            disableSpin = false,
            enabled = !startsDisabled,
            prop = null,
            glow = null,
            glowColor = "",
            glowEnabled = false
        };

        entry.disableSpin = (targetname.find("_nospin") != null);

        if (weaponModel != "")
        {
            entry.prop = MercWeaponSpawner_SpawnProp(entry);
            if (entry.prop != null)
                entry.glow = MercWeaponSpawner_SpawnGlow(entry, entry.prop);
        }

        if (!entry.enabled)
        {
            if (entry.prop != null && entry.prop.IsValid())
                MercWeaponSpawner_SetPropVisibleState(entry.prop, 0);
            MercWeaponSpawner_SetGlowEnabled(entry, false);
        }

        ::MercWeaponSpawner_Entries[targetname] <- entry;
    }
}

function MercWeaponSpawner_GiveWeapon(player, entry)
{
    if (MercWeaponSpawner_PlayerHasWeapon(player, entry.weaponItemDef, entry.weaponClass))
    {
        if ("MercDeathDrops_GiveAmmoMedium" in getroottable())
        {
            try { return MercDeathDrops_GiveAmmoMedium(player, entry.weaponItemDef, entry.weaponClass); } catch (eAmmo0) {}
        }
        return false;
    }

    local previousWeapon = MercWeaponSpawner_GetWeaponInSlot(player, ("weaponSlotIndex" in entry) ? entry.weaponSlotIndex : -1);
    local previousDropInfo = null;
    local previousItemDefId = -1;
    if (previousWeapon != null && "MercDeathDrops_BuildDropInfoFromWeaponEntity" in getroottable())
    {
        try { previousDropInfo = MercDeathDrops_BuildDropInfoFromWeaponEntity(previousWeapon); } catch (e0) { previousDropInfo = null; }
    }
    if (previousWeapon != null)
    {
        try { previousItemDefId = NetProps.GetPropInt(previousWeapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (eItem0) { previousItemDefId = -1; }
        if (previousItemDefId < 0)
            try { previousItemDefId = NetProps.GetPropInt(previousWeapon, "m_iItemDefinitionIndex"); } catch (eItem1) { previousItemDefId = -1; }
    }

    // Make melee replacement explicit so the default shovel cannot linger behind a picked-up
    // bottle/wrench and apply its -50 max-health stat a second time on later respawns.
    if (previousWeapon != null && ("weaponSlotIndex" in entry) && entry.weaponSlotIndex == 2 && previousItemDefId != entry.weaponItemDef)
    {
        if ("MercDeathDrops_RemoveWeaponEntityFromPlayer" in getroottable())
        {
            try { MercDeathDrops_RemoveWeaponEntityFromPlayer(player, previousWeapon); } catch (eRemove0) {}
        }
        else
        {
            try { previousWeapon.Destroy(); } catch (eRemove1) { try { previousWeapon.Kill(); } catch (eRemove2) {} }
        }
    }

    local weapon = GivePlayerWeapon(player, entry.weaponClass, entry.weaponItemDef);
    if (weapon == null)
        return false;

    try { MercWeaponSpawner_ApplyMercMeleePenalty(weapon, entry.weaponItemDef, entry.weaponClass); } catch (ePenalty0) {}

    try
    {
        if ("ApplyWeaponAmmoDefaults" in getroottable())
            ApplyWeaponAmmoDefaults(player, weapon, entry.weaponClass);
    }
    catch (e1) {}

    if (previousDropInfo != null && previousDropInfo.itemDefId != entry.weaponItemDef && "MercDeathDrops_SpawnWeaponDropForPlayer" in getroottable())
    {
        try { MercDeathDrops_SpawnWeaponDropForPlayer(player, previousDropInfo, 2.0); } catch (e2) {}
    }

    MercWeaponSpawner_MaybePlayAutograbVoice(player, entry.weaponItemDef);

    return true;
}

function MercWeaponSpawner_Update()
{
    local now = 0.0;
    try { now = Time(); } catch (e0) { now = 0.0; }
    local requireUseMode = MercWeaponSpawner_RequireUseToSwitchEnabled();

    foreach (name, entry in ::MercWeaponSpawner_Entries)
    {
        local prop = ("prop" in entry) ? entry.prop : null;
        if (prop != null)
        {
            try
            {
                if (!prop.IsValid())
                {
                    prop = entry.prop = MercWeaponSpawner_SpawnProp(entry);
                    entry.glow = null;
                    entry.glowColor = "";
                    entry.glowEnabled = false;
                }
            }
            catch (e1)
            {
                prop = entry.prop = MercWeaponSpawner_SpawnProp(entry);
                entry.glow = null;
                entry.glowColor = "";
                entry.glowEnabled = false;
            }
        }

        local glow = ("glow" in entry) ? entry.glow : null;
        if (prop != null && prop.IsValid() && (glow == null || !glow.IsValid()))
        {
            entry.glow = glow = MercWeaponSpawner_SpawnGlow(entry, prop);
            entry.glowColor = "";
            entry.glowEnabled = false;
        }

        if (prop != null && prop.IsValid())
        {
            if (!("disableSpin" in entry) || !entry.disableSpin)
            {
                entry.yaw = (entry.yaw + (MERC_WEAPON_ROTATE_SPEED * MERC_WEAPON_THINK_INTERVAL)) % 360.0;
                try { prop.SetAbsAngles(QAngle(0, entry.yaw, 0)); } catch (e2) {}
            }
        }

        if ("enabled" in entry && !entry.enabled)
        {
            if (prop != null && prop.IsValid())
                MercWeaponSpawner_SetPropVisibleState(prop, 0);
            MercWeaponSpawner_SetGlowEnabled(entry, false);
            continue;
        }

        local desiredGlowColor = MERC_WEAPON_GLOW_COLOR_TOUCH;
        local shouldEnableGlow = false;

        if (now < entry.respawnAt)
        {
            if (prop != null && prop.IsValid())
                MercWeaponSpawner_SetPropVisibleState(prop, MERC_WEAPON_COOLDOWN_ALPHA);
            MercWeaponSpawner_SetGlowEnabled(entry, false);
            if (!entry.respawnWarned && entry.respawnWarnAt > 0.0 && now >= entry.respawnWarnAt)
            {
                entry.respawnWarned = true;
                if ("respawnWarnRelay" in entry && entry.respawnWarnRelay != null && entry.respawnWarnRelay != "")
                    try { EntFire(entry.respawnWarnRelay, "Trigger", "", 0, null); } catch (eRespawnWarn) {}
            }
            continue;
        }

        if (prop != null && prop.IsValid())
            MercWeaponSpawner_SetPropVisibleState(prop, 255);
        MercWeaponSpawner_SetGlowEnabled(entry, false);

        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!MercWeaponSpawner_IsPlayablePlayer(player))
                continue;

            local delta = player.GetOrigin() - entry.origin;
            local horizontalDistSqr = (delta.x * delta.x) + (delta.y * delta.y);
            if (horizontalDistSqr > entry.touchRadiusSqr)
                continue;
            if (fabs(delta.z) > MERC_WEAPON_TOUCH_Z_TOLERANCE)
                continue;

            local occupiedSlotWeapon = MercWeaponSpawner_GetWeaponInSlot(player, ("weaponSlotIndex" in entry) ? entry.weaponSlotIndex : -1);
            if (requireUseMode && MercWeaponSpawner_RequiresUseToPickup(player, entry, occupiedSlotWeapon))
            {
                shouldEnableGlow = MERC_WEAPON_ENABLE_TOUCH_GLOW;
                if (!MercWeaponSpawner_IsUsePressed(player))
                {
                    if (MERC_WEAPON_ENABLE_TOUCH_GLOW)
                    {
                        MercWeaponSpawner_SetGlowEnabled(entry, true);
                        MercWeaponSpawner_SetGlowColor(entry, desiredGlowColor);
                    }
                    MercWeaponSpawner_ShowSwapPrompt(player, entry, occupiedSlotWeapon);
                    continue;
                }
                MercWeaponSpawner_ClearUsePromptCooldown(player);
            }

            if (MercWeaponSpawner_GiveWeapon(player, entry))
            {
                entry.respawnAt = now + entry.respawnDelay;
                entry.respawnWarnAt = entry.respawnAt - 15.0;
                entry.respawnWarned = false;
                if (prop != null && prop.IsValid())
                {
                    MercWeaponSpawner_SetPropVisibleState(prop, MERC_WEAPON_COOLDOWN_ALPHA);
                    MercWeaponSpawner_PlaySound(MERC_WEAPON_PICKUP_SOUND, prop);
                }
                if ("pickupRelay" in entry && entry.pickupRelay != null && entry.pickupRelay != "")
                    try { EntFire(entry.pickupRelay, "Trigger", "", 0, player); } catch (ePickupRelay) {}
            }
            break;
        }

        MercWeaponSpawner_SetGlowEnabled(entry, shouldEnableGlow);
        if (shouldEnableGlow)
            MercWeaponSpawner_SetGlowColor(entry, desiredGlowColor);

        if (entry.respawnAt > 0.0 && now >= entry.respawnAt)
        {
            if (prop != null && prop.IsValid())
                if (!MercWeaponSpawner_WeaponStayEnabled())
                    MercWeaponSpawner_PlaySound(MERC_WEAPON_RESPAWN_SOUND, prop);
            entry.respawnAt = 0.0;
        }
    }
}

getroottable()["MercWeaponSpawner_EnableByOrigin"] <- MercWeaponSpawner_EnableByOrigin;
getroottable()["MercWeaponSpawner_DisableByOrigin"] <- MercWeaponSpawner_DisableByOrigin;
getroottable()["MercWeaponSpawner_EnableByCoords"] <- MercWeaponSpawner_EnableByCoords;
getroottable()["MercWeaponSpawner_DisableByCoords"] <- MercWeaponSpawner_DisableByCoords;
getroottable()["MercWeaponSpawner_ResetByCoords"] <- MercWeaponSpawner_ResetByCoords;
getroottable()["MercWeaponSpawner_HandleWarheadGIBPickup"] <- MercWeaponSpawner_HandleWarheadGIBPickup;

getroottable()["MercWeaponSpawner_Tick"] <- function(hostEnt, serial)
{
    if (serial != ::MercWeaponSpawner_ThinkSerial)
        return;

    local runtimeHost = hostEnt;
    if (runtimeHost == null)
        runtimeHost = ::MercWeaponSpawner_RuntimeHost;

    try { MercWeaponSpawner_Update(); } catch (e0) {}

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        local code = format("try{ MercWeaponSpawner_Tick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_WEAPON_THINK_INTERVAL, null, null); } catch (e1) {}
    }
}

function MercWeaponSpawner_StartThink(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null)
    {
        try { runtimeHost = self; } catch (e0) { runtimeHost = null; }
    }
    if (runtimeHost == null)
    {
        try { runtimeHost = Entities.FindByClassname(null, "logic_script"); } catch (e1) { runtimeHost = null; }
        if (runtimeHost == null)
            try { runtimeHost = Entities.FindByClassname(null, "worldspawn"); } catch (e2) { runtimeHost = null; }
    }

    if (runtimeHost == null || !runtimeHost.IsValid())
        return;

    ::MercWeaponSpawner_RuntimeHost = runtimeHost;
    ::MercWeaponSpawner_ThinkSerial += 1;
    local serial = ::MercWeaponSpawner_ThinkSerial;

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        try
        {
            runtimeHost.SetContextThink("MercWeaponSpawnerThink", function()
            {
                try { MercWeaponSpawner_Update(); } catch (e2) {}
                return MERC_WEAPON_THINK_INTERVAL;
            }, MERC_WEAPON_THINK_INTERVAL);
        }
        catch (e3) {}

        local code = format("try{ MercWeaponSpawner_Tick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_WEAPON_THINK_INTERVAL, null, null); } catch (e4) {}
    }
}

function MercWeaponSpawner_Precache()
{
    try { PrecacheSound(MERC_WEAPON_PICKUP_SOUND); } catch (e0) {}
    try { PrecacheSound("items/gunpickup2.wav"); } catch (e0a) {}
    try { PrecacheSound(MERC_WEAPON_RESPAWN_SOUND); } catch (e1) {}
    try { PrecacheSound(MERC_WEAPON_USE_PROMPT_SOUND); } catch (e2) {}
    foreach (snd in ::MercWeaponSpawner_AutograbVoices)
        try { PrecacheSound(snd); } catch (e3) {}
    foreach (snd in ::MercWeaponSpawner_TwinBarrelPickupVoices)
        try { PrecacheSound(snd); } catch (e4) {}
    foreach (snd in ::MercWeaponSpawner_AAGunPickupVoices)
        try { PrecacheSound(snd); } catch (e5) {}
}

function Activate()
{
    MercWeaponSpawner_Precache();

    local host = null;
    try { host = self; } catch (e0) { host = null; }
    if (host == null)
        try { host = Entities.FindByClassname(null, "logic_script"); } catch (e1) { host = null; }
    if (host == null)
        try { host = Entities.FindByClassname(null, "worldspawn"); } catch (e2) { host = null; }

    if (host != null && host.IsValid())
    {
        EntFireByHandle(host, "RunScriptCode", "MercWeaponSpawner_DiscoverMarkers();", 0.20, null, null);
        EntFireByHandle(host, "RunScriptCode", "MercWeaponSpawner_StartThink(self);", 0.25, null, null);
    }
    else
    {
        MercWeaponSpawner_DiscoverMarkers();
        MercWeaponSpawner_StartThink(host);
    }
}

getroottable()["MercWeaponSpawner_DiscoverMarkers"] <- MercWeaponSpawner_DiscoverMarkers;
getroottable()["MercWeaponSpawner_StartThink"] <- MercWeaponSpawner_StartThink;

Activate();
