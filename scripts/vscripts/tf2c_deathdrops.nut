// tf2c_deathdrops.nut
//
// Runtime ammo/weapon drops for Merc DM.

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
__IncludeScriptOnce("tf2c_dmrando.nut");

const MERC_DROP_AMMO_MODEL = "models/items/ammopack_medium.mdl";
const MERC_DROP_PICKUP_DELAY = 1.0;
const MERC_DROP_SWAP_PICKUP_DELAY = 2.0;
const MERC_DROP_OWNER_BLOCK_DELAY = 2.0;
const MERC_DROP_TOUCH_RADIUS = 56.0;
const MERC_DROP_TOUCH_RADIUS_USE = 96.0;
const MERC_DROP_TOUCH_Z_TOLERANCE = 72.0;
const MERC_DROP_THINK_INTERVAL = 0.05;
const MERC_DROP_PICKUP_SOUND = "AmmoPack.Touch";
const MERC_DROP_GLOW_MODE = 1;
const MERC_DROP_GLOW_COLOR_TOUCH = "255 255 255 255";
const MERC_DROP_ENABLE_TOUCH_GLOW = false;
const MERC_DROP_USE_PROMPT = "Press F (+use) to switch";
const MERC_DROP_USE_PROMPT_INTERVAL = 4.0;
const MERC_DROP_USE_PROMPT_SOUND = "Hud.Hint";
const MERC_DROP_AUTOGRAB_CHANCE = 0.18;
const MERC_DROP_AUTOGRAB_SOUNDLEVEL = 70;
const MERC_DROP_AUTOGRAB_VOLUME = 0.65;
const IN_USE = 32;

::MercDeathDrops_RuntimeHost <- null;
::MercDeathDrops_ThinkSerial <- 0;
::MercDeathDrops_Entries <- {};
::MercDeathDrops_NextId <- 0;
::MercDeathDrops_LastUsePromptTime <- {};
::MercDeathDrops_PromptEntities <- {};
::MercDeathDrops_AutograbVoices <- [
    "vo/customclass/mercenary/mercenary_autograbbedintelligence01.mp3",
    "vo/customclass/mercenary/mercenary_autograbbedintelligence02.mp3",
    "vo/customclass/mercenary/mercenary_autograbbedintelligence03.mp3"
];
::MercDeathDrops_TwinBarrelPickupVoices <- [
    "vo/customclass/mercenary/mercenary_pickup_supershotgun02.mp3",
    "vo/customclass/mercenary/mercenary_positivevocalization02.mp3"
];
::MercDeathDrops_AAGunPickupVoices <- [
    "vo/customclass/mercenary/mercenary_specialcompleted999.mp3"
];
::MercDeathDrops_FriendlyNamesByItemDef <- {
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
::MercDeathDrops_FriendlyNamesByClass <- {
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

::MercDeathDrops_ModelOverrides <-
{
    [9] = "models/weapons/w_models/w_shotgun.mdl",
    [10] = "models/weapons/w_models/w_shotgun.mdl",
    [16] = "models/weapons/w_models/w_smg.mdl",
    [18] = "models/weapons/w_models/w_rocketlauncher.mdl",
    [19] = "models/weapons/w_models/w_grenadelauncher.mdl",
    [35] = "models/weapons/w_models/w_flaregun.mdl",
    [5] = "models/weapons/w_models/w_bat.mdl",
    [2001] = "models/weapons/w_models/w_nailgun.mdl",
    [2002] = "models/weapons/w_models/w_rpg.mdl",
    [2006] = "models/weapons/w_models/w_grenade_mirv_demo.mdl",
    [2013] = "models/weapons/w_models/w_twinbarrel.mdl",
    [2014] = "models/weapons/w_models/w_aagun.mdl",
    [2018] = "models/weapons/w_models/w_nader.mdl",
    [2020] = "models/weapons/w_models/w_speedcane.mdl",
    [2021] = "models/weapons/w_models/w_cyclops.mdl"
};

::MercDeathDrops_AmmoReserveCaps <-
{
    ["tf2c_weapon_aagun"] = 120,
    ["tf2c_weapon_cyclops"] = 16,
    ["tf2c_weapon_doubleshotgun"] = 32,
    ["tf2c_weapon_heallauncher"] = 24,
    ["tf2c_weapon_nailgun"] = 120,
    ["tf_weapon_flamethrower"] = 200,
    ["tf_weapon_flaregun"] = 16,
    ["tf_weapon_grenade_mirv"] = 4,
    ["tf_weapon_grenadelauncher"] = 16,
    ["tf_weapon_minigun"] = 200,
    ["tf_weapon_pipebomblauncher"] = 24,
    ["tf_weapon_pistol"] = 200,
    ["tf_weapon_rocketlauncher"] = 20,
    ["tf_weapon_scattergun"] = 32,
    ["tf_weapon_shotgun_primary"] = 32,
    ["tf_weapon_shotgun_soldier"] = 32,
    ["tf_weapon_shotgun_hwg"] = 32,
    ["tf_weapon_shotgun_pyro"] = 32,
    ["tf_weapon_smg"] = 75,
    ["tf_weapon_sniperrifle"] = 25,
    ["tf_weapon_syringegun_medic"] = 150
};

::MercDeathDrops_ClassModelOverrides <-
{
    ["tf2c_weapon_aagun"] = "models/weapons/w_models/w_aagun.mdl",
    ["tf2c_weapon_chains"] = "models/weapons/w_models/w_chekhovspunch.mdl",
    ["tf2c_weapon_coilgun"] = "models/weapons/w_models/w_coilgun.mdl",
    ["tf2c_weapon_cyclops"] = "models/weapons/w_models/w_cyclops.mdl",
    ["tf2c_weapon_doubleshotgun"] = "models/weapons/w_models/w_twinbarrel.mdl",
    ["tf2c_weapon_hunting_revolver"] = "models/weapons/w_models/w_revrifle_sniper.mdl",
    ["tf2c_weapon_nailgun"] = "models/weapons/w_models/w_nailgun.mdl",
    ["tf2c_weapon_nader"] = "models/weapons/w_models/w_nader.mdl",
    ["tf2c_weapon_scythe"] = "models/weapons/w_models/w_scythe.mdl",
    ["tf2c_weapon_tranq"] = "models/weapons/w_models/w_tranq.mdl",
    ["tf2c_weapon_umbrella"] = "models/weapons/w_models/w_umbrella.mdl",
    ["tf_weapon_bat"] = "models/weapons/w_models/w_bat.mdl",
    ["tf_weapon_flaregun"] = "models/weapons/w_models/w_flaregun.mdl",
    ["tf_weapon_grenade_mirv"] = "models/weapons/w_models/w_grenade_mirv_demo.mdl",
    ["tf_weapon_grenadelauncher"] = "models/weapons/w_models/w_grenadelauncher.mdl",
    ["tf_weapon_rocketlauncher"] = "models/weapons/w_models/w_rocketlauncher.mdl",
    ["tf_weapon_shotgun"] = "models/weapons/w_models/w_shotgun.mdl",
    ["tf_weapon_shotgun_primary"] = "models/weapons/w_models/w_shotgun.mdl",
    ["tf_weapon_shotgun_soldier"] = "models/weapons/w_models/w_shotgun.mdl",
    ["tf_weapon_smg"] = "models/weapons/w_models/w_smg.mdl",
    ["tf_weapon_sniperrifle"] = "models/weapons/w_models/w_sniperrifle.mdl",
    ["tf_weapon_syringegun_medic"] = "models/weapons/w_models/w_syringegun.mdl"
};

function MercDeathDrops_IsPlayablePlayer(player)
{
    if (player == null || !player.IsValid())
        return false;
    try
    {
        if (!player.IsPlayer())
            return false;
    }
    catch (e0) { return false; }

    try
    {
        if ("IsAlive" in player && !player.IsAlive())
            return false;
    }
    catch (eAlive0) {}

    if ("NetProps" in getroottable())
    {
        local lifeState = 0;
        try { lifeState = NetProps.GetPropInt(player, "m_lifeState"); } catch (eAlive1) { lifeState = 0; }
        if (lifeState != 0)
            return false;
    }

    local team = 0;
    try { team = player.GetTeam(); } catch (e1) { team = 0; }
    return team >= 2;
}

function MercDeathDrops_ParseInt(value, fallback)
{
    try { return value.tointeger(); } catch (e0) {}
    try { return value.tostring().tointeger(); } catch (e1) {}
    return fallback;
}

function MercDeathDrops_PlaySound(soundName, ent)
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

function MercDeathDrops_PlaySoundAtPlayer(soundName, player)
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
        volume = MERC_DROP_AUTOGRAB_VOLUME,
        pitch = 100,
        soundlevel = MERC_DROP_AUTOGRAB_SOUNDLEVEL
    };
    try { EmitSoundEx(params); } catch (e0) {}
}

function MercDeathDrops_ApplyMercMeleePenalty(weapon, itemDefId, weaponClass)
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

function MercDeathDrops_IsBotPlayer(player)
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

function MercDeathDrops_MaybePlayAutograbVoice(player, itemDefId = -1)
{
    if (player == null || !player.IsValid())
        return;

    local roll = 1.0;
    try { roll = RandomFloat(0.0, 1.0); } catch (e0) { roll = 1.0; }
    if (roll > MERC_DROP_AUTOGRAB_CHANCE)
        return;

    local voicePool = ::MercDeathDrops_AutograbVoices;
    if (itemDefId == 2013)
        voicePool = ::MercDeathDrops_TwinBarrelPickupVoices;
    else if (itemDefId == 2014)
        voicePool = ::MercDeathDrops_AAGunPickupVoices;

    local idx = 0;
    try { idx = RandomInt(0, voicePool.len() - 1); } catch (e1) { idx = 0; }
    if (idx < 0 || idx >= voicePool.len())
        idx = 0;
    MercDeathDrops_PlaySoundAtPlayer(voicePool[idx], player);
}

function MercDeathDrops_GetWeaponDef(itemDefId)
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

function MercDeathDrops_GetFriendlyWeaponName(itemDefId, weaponClass = null, fallbackName = "")
{
    if (itemDefId in ::MercDeathDrops_FriendlyNamesByItemDef)
        return ::MercDeathDrops_FriendlyNamesByItemDef[itemDefId];

    if (weaponClass != null && weaponClass in ::MercDeathDrops_FriendlyNamesByClass)
        return ::MercDeathDrops_FriendlyNamesByClass[weaponClass];

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

function MercDeathDrops_GetWeaponDisplayNameFromDef(def, fallbackName = "Weapon")
{
    local itemDefId = -1;
    local weaponClass = null;
    try { if ("id" in def) itemDefId = def.id; } catch (eId) { itemDefId = -1; }
    try { if ("itemClass" in def) weaponClass = MercDeathDrops_ResolveGiveClass(def); } catch (eClass) { weaponClass = null; }
    if (def != null)
    {
        try
        {
            if ("name" in def && def.name != null && def.name != "")
                return MercDeathDrops_GetFriendlyWeaponName(itemDefId, weaponClass, def.name);
        }
        catch (e0) {}
    }
    return MercDeathDrops_GetFriendlyWeaponName(itemDefId, weaponClass, fallbackName);
}

function MercDeathDrops_GetWeaponDisplayNameFromEntity(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return "weapon";

    local itemDefId = MercDeathDrops_GetWeaponEntityItemDef(weapon);
    if (itemDefId >= 0)
    {
        local def = MercDeathDrops_GetWeaponDef(itemDefId);
        local resolved = MercDeathDrops_GetWeaponDisplayNameFromDef(def, "");
        if (resolved != "")
            return resolved;
    }

    local className = "weapon";
    try { className = weapon.GetClassname(); } catch (e1) { className = "weapon"; }
    return MercDeathDrops_GetFriendlyWeaponName(itemDefId, className, className);
}

function MercDeathDrops_GetEntryDisplayName(entry)
{
    local itemDefId = -1;
    try { itemDefId = entry.itemDefId; } catch (e0) { itemDefId = -1; }
    if (itemDefId >= 0)
    {
        local def = MercDeathDrops_GetWeaponDef(itemDefId);
        local resolved = MercDeathDrops_GetWeaponDisplayNameFromDef(def, "");
        if (resolved != "")
            return resolved;
    }

    local giveClass = "weapon";
    try { giveClass = entry.giveClass; } catch (e1) { giveClass = "weapon"; }
    return MercDeathDrops_GetFriendlyWeaponName(itemDefId, giveClass, giveClass);
}

function MercDeathDrops_ShowUsePrompt(player, entry, occupiedSlotWeapon)
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
    if (entIdx in ::MercDeathDrops_LastUsePromptTime)
        last = ::MercDeathDrops_LastUsePromptTime[entIdx];
    if ((now - last) < MERC_DROP_USE_PROMPT_INTERVAL)
        return;

    ::MercDeathDrops_LastUsePromptTime[entIdx] <- now;
    local currentName = MercDeathDrops_GetWeaponDisplayNameFromEntity(occupiedSlotWeapon);
    local pickupName = MercDeathDrops_GetEntryDisplayName(entry);
    local prompt = format("Press F (+use) to swap %s for %s", currentName, pickupName);
    local promptEnt = null;
    if (entIdx in ::MercDeathDrops_PromptEntities)
        promptEnt = ::MercDeathDrops_PromptEntities[entIdx];
    if (promptEnt == null || !promptEnt.IsValid())
    {
        try
        {
            promptEnt = SpawnEntityFromTable("game_text",
            {
                targetname = format("__merc_drop_prompt_%d", entIdx),
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
            ::MercDeathDrops_PromptEntities[entIdx] <- promptEnt;
    }
    if (promptEnt != null && promptEnt.IsValid())
    {
        try { promptEnt.__KeyValueFromString("message", prompt); } catch (e2) {}
        try { EntFireByHandle(promptEnt, "Display", "", 0.0, player, player); } catch (e3) {}
    }
    else
        try { ClientPrint(player, 4, prompt); } catch (e4) {}
    try { EmitSoundOn(MERC_DROP_USE_PROMPT_SOUND, player); } catch (e5) { try { MercDeathDrops_PlaySound(MERC_DROP_USE_PROMPT_SOUND, player); } catch (e6) {} }
}

function MercDeathDrops_ClearUsePromptCooldown(player)
{
    if (player == null || !player.IsValid())
        return;

    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    if (entIdx < 0)
        return;

    if (entIdx in ::MercDeathDrops_LastUsePromptTime)
        delete ::MercDeathDrops_LastUsePromptTime[entIdx];

    local promptEnt = null;
    if (entIdx in ::MercDeathDrops_PromptEntities)
        promptEnt = ::MercDeathDrops_PromptEntities[entIdx];
    if (promptEnt != null && promptEnt.IsValid())
    {
        try { promptEnt.__KeyValueFromString("message", " "); } catch (e1) {}
        try { EntFireByHandle(promptEnt, "Display", "", 0.0, player, player); } catch (e2) {}
    }
}

function MercDeathDrops_ResolveGiveClass(def)
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

function MercDeathDrops_ResolveSlotIndex(def, giveClass)
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

    if (giveClass == null)
        return -1;
    if (giveClass.find("shotgun") != null || giveClass.find("grenadelauncher") != null || giveClass.find("rocketlauncher") != null || giveClass.find("sniperrifle") != null)
        return 0;
    if (giveClass.find("smg") != null || giveClass.find("flaregun") != null || giveClass.find("syringegun") != null || giveClass.find("pistol") != null)
        return 1;
    if (giveClass.find("shovel") != null || giveClass.find("bat") != null || giveClass.find("knife") != null || giveClass.find("wrench") != null || giveClass.find("bottle") != null)
        return 2;
    return -1;
}

function MercDeathDrops_ResolveWorldModel(itemDefId, def)
{
    if (def != null)
    {
        try
        {
            if ("modelWorld" in def && def.modelWorld != null && def.modelWorld != "")
                return def.modelWorld;
        }
        catch (e0) {}

        try
        {
            if ("model_player" in def && def.model_player != null && def.model_player != "")
                return def.model_player;
        }
        catch (e1) {}

        try
        {
            if ("itemClass" in def && def.itemClass in ::MercDeathDrops_ClassModelOverrides)
                return ::MercDeathDrops_ClassModelOverrides[def.itemClass];
        }
        catch (e2) {}
    }

    if (itemDefId in ::MercDeathDrops_ModelOverrides)
        return ::MercDeathDrops_ModelOverrides[itemDefId];

    return "";
}

function MercDeathDrops_GetActiveWeapon(player)
{
    if (player == null || !player.IsValid())
        return null;

    local weapon = null;
    try
    {
        if ("GetActiveWeapon" in player)
            weapon = player.GetActiveWeapon();
    }
    catch (e0) { weapon = null; }

    if (weapon == null && "NetProps" in getroottable())
    {
        try { weapon = NetProps.GetPropEntity(player, "m_hActiveWeapon"); } catch (e1) { weapon = null; }
    }
    return weapon;
}

function MercDeathDrops_GetTeamSkinIndex(player)
{
    if (player == null || !player.IsValid())
        return 0;

    local team = 0;
    try { team = player.GetTeam(); } catch (e0) { team = 0; }
    if (team == 3) return 1;
    if (team == 4) return 2;
    if (team == 5) return 3;
    return 0;
}

function MercDeathDrops_SpawnPhysicsProp(name, modelPath, origin, skin = 0, forceWeaponSkinInput = false)
{
    if (modelPath == null || modelPath == "")
        return null;

    try { PrecacheModel(modelPath); } catch (ePrecache) {}

    local kv =
    {
        targetname = name,
        model = modelPath,
        origin = format("%f %f %f", origin.x, origin.y, origin.z + 8.0),
        angles = "0 0 0",
        skin = skin.tostring(),
        disableshadows = 1,
        rendermode = 1,
        renderamt = 255,
        rendercolor = "255 255 255"
    };

    local ent = null;
    try { ent = SpawnEntityFromTable("prop_physics_override", kv); } catch (e0) { ent = null; }
    if (ent == null)
        try { ent = SpawnEntityFromTable("prop_physics", kv); } catch (e1) { ent = null; }
    if (ent == null)
    {
        local fallbackKv =
        {
            targetname = name,
            model = modelPath,
            origin = kv.origin,
            angles = kv.angles,
            skin = skin.tostring(),
            disableshadows = 1,
            rendermode = 1,
            renderamt = 255,
            rendercolor = "255 255 255"
        };
        try { ent = SpawnEntityFromTable("prop_dynamic_override", fallbackKv); } catch (e2) { ent = null; }
        if (ent == null)
            try { ent = SpawnEntityFromTable("prop_dynamic", fallbackKv); } catch (e3) { ent = null; }
    }
    if (ent != null)
    {
        try { if ("SetSkin" in ent) ent.SetSkin(skin); } catch (e3b) {}
        // Keep world collision so the drop rests on the map, but use a lighter
        // collision group so it does not body-block players like a normal prop.
        try { if ("NetProps" in getroottable()) NetProps.SetPropInt(ent, "m_CollisionGroup", 1); } catch (e6) {}
        try { if ("NetProps" in getroottable()) NetProps.SetPropInt(ent, "m_nSkin", skin); } catch (e8) {}
        if (forceWeaponSkinInput)
        {
            try { EntFireByHandle(ent, "Skin", skin.tostring(), 0.0, null, null); } catch (e3c) {}
            try { EntFireByHandle(ent, "Skin", skin.tostring(), 0.05, null, null); } catch (e3d) {}
            try { EntFireByHandle(ent, "Skin", skin.tostring(), 0.15, null, null); } catch (e3e) {}
        }
    }
    return ent;
}

function MercDeathDrops_SpawnGlow(name, prop)
{
    if (prop == null || !prop.IsValid())
        return null;

    local targetName = "";
    try { targetName = prop.GetName(); } catch (e0) { targetName = ""; }
    if (targetName == "")
        return null;

    local kv =
    {
        targetname = name + "_glow",
        target = targetName,
        Mode = MERC_DROP_GLOW_MODE,
        GlowColor = MERC_DROP_GLOW_COLOR_TOUCH,
        StartDisabled = 1
    };

    local glow = null;
    try { glow = SpawnEntityFromTable("tf_glow", kv); } catch (e1) { glow = null; }
    return glow;
}

function MercDeathDrops_SetGlowColor(entry, colorValue)
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

function MercDeathDrops_SetGlowEnabled(entry, enabled)
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

function MercDeathDrops_RemoveManagedEntity(ent)
{
    if (ent == null)
        return;

    local valid = false;
    try { valid = ent.IsValid(); } catch (e0) { valid = false; }
    if (!valid)
        return;

    try { ent.Kill(); } catch (e1) {}
    try { ent.Destroy(); } catch (e2) {}
    try { EntFireByHandle(ent, "Kill", "", 0.0, null, null); } catch (e3) {}
}

function MercDeathDrops_RemoveWeaponEntityFromPlayer(player, weapon)
{
    if (player == null || !player.IsValid() || weapon == null || !weapon.IsValid())
        return;

    local removed = false;
    try { weapon.Destroy(); removed = true; } catch (e0) {}
    if (!removed)
        try { weapon.Kill(); removed = true; } catch (e1) {}

    if ("NetProps" in getroottable())
    {
        for (local i = 0; i < 8; i++)
        {
            local held = null;
            try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e2) { held = null; }
            if (held != weapon)
                continue;
            try { NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); } catch (e3) {}
            break;
        }
    }
}

function MercDeathDrops_GetLifetimeForKind(kind)
{
    if (kind == "weapon" && "__Merc_DroppedWeaponDespawnTime" in getroottable())
    {
        try { return __Merc_DroppedWeaponDespawnTime(); } catch (e0) {}
    }
    if (kind == "ammo" && "__Merc_DroppedAmmoBoxDespawnTime" in getroottable())
    {
        try { return __Merc_DroppedAmmoBoxDespawnTime(); } catch (e1) {}
    }
    return 15.0;
}

function MercDeathDrops_RecordDrop(kind, prop, itemDefId, giveClass, pickupDelay = MERC_DROP_PICKUP_DELAY, ownerEntIndex = -1, slotIndex = -1)
{
    if (prop == null || !prop.IsValid())
        return;

    local name = "";
    try { name = prop.GetName(); } catch (e0) { name = ""; }
    if (name == "")
    {
        name = format("merc_drop_%d", ::MercDeathDrops_NextId);
        ::MercDeathDrops_NextId += 1;
        try { prop.__KeyValueFromString("targetname", name); } catch (e1) {}
    }

    local now = 0.0;
    try { now = Time(); } catch (e2) { now = 0.0; }

    local entry =
    {
        name = name,
        kind = kind,
        prop = prop,
        glow = null,
        glowColor = "",
        glowEnabled = false,
        itemDefId = itemDefId,
        giveClass = giveClass,
        slotIndex = slotIndex,
        expireAt = now + MercDeathDrops_GetLifetimeForKind(kind),
        pickupAt = now + pickupDelay,
        ownerEntIndex = ownerEntIndex,
        ownerBlockUntil = now + MERC_DROP_OWNER_BLOCK_DELAY,
        touchRadiusSqr = MERC_DROP_TOUCH_RADIUS * MERC_DROP_TOUCH_RADIUS
    };

    if (kind == "weapon")
    {
        try { entry.glow = MercDeathDrops_SpawnGlow(name, prop); } catch (eGlowCreate) { entry.glow = null; }
    }

    local lifetime = MercDeathDrops_GetLifetimeForKind(kind);
    try { EntFireByHandle(prop, "Kill", "", lifetime, null, null); } catch (e4) {}
    if (entry.glow != null)
        try { EntFireByHandle(entry.glow, "Kill", "", lifetime, null, null); } catch (e5) {}

    ::MercDeathDrops_Entries[name] <- entry;
}

function MercDeathDrops_GetWeaponEntityItemDef(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return -1;

    local itemDefId = -1;
    try { itemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e0) { itemDefId = -1; }
    if (itemDefId < 0)
    {
        try { itemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e1) { itemDefId = -1; }
    }
    return itemDefId;
}

function MercDeathDrops_PlayerHasWeapon(player, itemDefId, giveClass = null)
{
    if (player == null || !player.IsValid())
        return false;
    if (!("NetProps" in getroottable()))
        return false;

    for (local i = 0; i < 8; i++)
    {
        local weapon = null;
        try { weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e0) { weapon = null; }
        if (weapon == null)
            continue;

        local heldItemDefId = MercDeathDrops_GetWeaponEntityItemDef(weapon);
        if (heldItemDefId >= 0 && heldItemDefId == itemDefId)
            return true;

        if (heldItemDefId < 0 && itemDefId < 0 && giveClass != null && giveClass != "")
        {
            local className = null;
            try { className = weapon.GetClassname(); } catch (e1) { className = null; }
            if (className != null && className == giveClass)
                return true;
        }
    }

    return false;
}

function MercDeathDrops_GetWeaponInSlot(player, slotIndex)
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

function MercDeathDrops_IsPistolWeapon(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return false;

    local className = null;
    try { className = weapon.GetClassname(); } catch (e0) { className = null; }
    if (className == "tf_weapon_pistol")
        return true;

    local itemDefId = MercDeathDrops_GetWeaponEntityItemDef(weapon);
    return (itemDefId == 22 || itemDefId == 23);
}

function MercDeathDrops_RequiresUseToPickup(player, entry)
{
    if (MercDeathDrops_IsBotPlayer(player))
        return false;
    if (!__Merc_DropWeaponsUseEnabled())
        return false;

    local slotIndex = ("slotIndex" in entry) ? entry.slotIndex : -1;
    local occupiedSlotWeapon = MercDeathDrops_GetWeaponInSlot(player, slotIndex);
    if (occupiedSlotWeapon == null)
        return false;

    local occupiedItemDefId = MercDeathDrops_GetWeaponEntityItemDef(occupiedSlotWeapon);
    local targetItemDefId = -1;
    try { targetItemDefId = entry.itemDefId; } catch (eItem0) { targetItemDefId = -1; }
    if (occupiedItemDefId >= 0 && targetItemDefId >= 0 && occupiedItemDefId == targetItemDefId)
        return false;

    if (slotIndex == 1 && "__Merc_WeaponSpawnersReplacePistolEnabled" in getroottable())
    {
        local allowPistolReplace = false;
        try { allowPistolReplace = __Merc_WeaponSpawnersReplacePistolEnabled(); } catch (e0) { allowPistolReplace = false; }
        if (allowPistolReplace && MercDeathDrops_IsPistolWeapon(occupiedSlotWeapon))
            return false;
    }

    return true;
}

function MercDeathDrops_GetTouchRadiusSqrForEntry(entry)
{
    if (entry == null)
        return MERC_DROP_TOUCH_RADIUS * MERC_DROP_TOUCH_RADIUS;
    if (entry.kind == "weapon" && __Merc_DropWeaponsUseEnabled())
        return MERC_DROP_TOUCH_RADIUS_USE * MERC_DROP_TOUCH_RADIUS_USE;
    return entry.touchRadiusSqr;
}

function MercDeathDrops_BuildDropInfoFromWeaponEntity(weapon)
{
    if (weapon == null || !weapon.IsValid())
        return null;

    local className = null;
    try { className = weapon.GetClassname(); } catch (e0) { className = null; }
    if (className == null)
        return null;
    if (className == "tf_weapon_shovel" || className == "tf_weapon_pistol")
        return null;

    local itemDefId = MercDeathDrops_GetWeaponEntityItemDef(weapon);
    if (itemDefId < 0)
        return null;

    local def = MercDeathDrops_GetWeaponDef(itemDefId);
    if (def == null)
        return null;

    local giveClass = MercDeathDrops_ResolveGiveClass(def);
    local worldModel = MercDeathDrops_ResolveWorldModel(itemDefId, def);
    if (giveClass == null || worldModel == "")
        return null;

    return {
        itemDefId = itemDefId,
        giveClass = giveClass,
        slotIndex = MercDeathDrops_ResolveSlotIndex(def, giveClass),
        worldModel = worldModel
    };
}

function MercDeathDrops_SpawnWeaponDropForPlayer(player, dropInfo, pickupDelay)
{
    if (player == null || !player.IsValid() || dropInfo == null)
        return null;

    local origin = player.GetOrigin();
    local dropId = ::MercDeathDrops_NextId;
    ::MercDeathDrops_NextId += 1;
    local skin = MercDeathDrops_GetTeamSkinIndex(player);
    local team = 0;
    try { team = player.GetTeam(); } catch (eTeam0) { team = 0; }
    local forceWeaponSkinInput = (skin > 0);

    local weaponProp = MercDeathDrops_SpawnPhysicsProp(
        format("merc_drop_weapon_%d", dropId),
        dropInfo.worldModel,
        origin,
        skin,
        forceWeaponSkinInput
    );
    if (weaponProp != null)
    {
        local ownerEntIndex = -1;
        try { ownerEntIndex = player.entindex(); } catch (e0) { ownerEntIndex = -1; }
        local effectivePickupDelay = pickupDelay;
        if (__Merc_DropWeaponsUseEnabled() && effectivePickupDelay > 0.65)
            effectivePickupDelay = 0.65;
        MercDeathDrops_RecordDrop("weapon", weaponProp, dropInfo.itemDefId, dropInfo.giveClass, effectivePickupDelay, ownerEntIndex, ("slotIndex" in dropInfo) ? dropInfo.slotIndex : -1);
    }
    return weaponProp;
}

function MercDeathDrops_FindOwnedWeaponForAmmoRefill(player, targetItemDefId = -1, targetWeaponClass = null)
{
    if (!("NetProps" in getroottable()) || player == null || !player.IsValid())
        return null;

    for (local i = 0; i < 8; i++)
    {
        local weapon = null;
        try { weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e0) { weapon = null; }
        if (weapon == null)
            continue;

        local className = null;
        try { className = weapon.GetClassname(); } catch (e1) { className = null; }

        local itemDefId = -1;
        try { itemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e2) { itemDefId = -1; }
        if (itemDefId < 0)
            try { itemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e3) { itemDefId = -1; }

        if (targetItemDefId >= 0 && itemDefId == targetItemDefId)
            return weapon;
        if (targetWeaponClass != null && targetWeaponClass != "" && className == targetWeaponClass)
            return weapon;
    }

    return null;
}

function MercDeathDrops_GetWeaponSpecificReserveCap(player, weapon, className = null, itemDefId = -1)
{
    if (player == null || weapon == null)
        return null;

    if (className == null)
    {
        try { className = weapon.GetClassname(); } catch (e0) { className = null; }
    }
    if (itemDefId < 0)
    {
        try { itemDefId = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (e1) { itemDefId = -1; }
        if (itemDefId < 0)
            try { itemDefId = NetProps.GetPropInt(weapon, "m_iItemDefinitionIndex"); } catch (e2) { itemDefId = -1; }
    }

    local clipCount = null;
    local maxCount = null;
    if ("g_WeaponAmmoDefaults" in getroottable() && className != null && className in g_WeaponAmmoDefaults)
    {
        local def = g_WeaponAmmoDefaults[className];
        try { clipCount = def.clip; } catch (e3) { clipCount = null; }
        try { maxCount = def.max; } catch (e4) { maxCount = null; }
    }

    // TF2C RPG shares tf_weapon_rocketlauncher but spawns with a different loaded-round profile.
    if (itemDefId == 2002 && maxCount != null)
        clipCount = 1;

    if (maxCount == null)
        return null;

    local reserveCap = null;
    if ("__ComputeReserveFromDefaults" in getroottable())
    {
        try { reserveCap = __ComputeReserveFromDefaults(clipCount, maxCount); } catch (e5) { reserveCap = null; }
    }
    if (reserveCap == null)
    {
        if (clipCount == null || clipCount < 0)
            reserveCap = maxCount;
        else
            reserveCap = max(0, maxCount - clipCount);
    }

    return reserveCap;
}

function MercDeathDrops_GiveAmmoMedium(player, targetItemDefId = -1, targetWeaponClass = null)
{
    if (!("NetProps" in getroottable()))
        return false;

    local packRatio = 0.5;
    local touchedAmmoTypes = {};
    local gaveAny = false;
    local targetedWeapon = MercDeathDrops_FindOwnedWeaponForAmmoRefill(player, targetItemDefId, targetWeaponClass);

    for (local i = 0; i < 8; i++)
    {
        local weapon = null;
        try { weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e0) { weapon = null; }
        if (weapon == null)
            continue;
        if (targetedWeapon != null && weapon != targetedWeapon)
            continue;

        local className = null;
        try { className = weapon.GetClassname(); } catch (e1) { className = null; }
        if (className == null)
            continue;

        local cap = null;
        if (className in ::MercDeathDrops_AmmoReserveCaps)
            cap = ::MercDeathDrops_AmmoReserveCaps[className];
        if (cap == null)
            continue;

        local ammoType = -1;
        try { ammoType = NetProps.GetPropInt(weapon, "m_iPrimaryAmmoType"); } catch (e2) { ammoType = -1; }
        if (ammoType < 0)
            continue;

        local ammoTypeKey = ammoType.tostring();
        if (ammoTypeKey in touchedAmmoTypes)
            continue;
        touchedAmmoTypes[ammoTypeKey] <- true;

        local currentReserve = 0;
        try { currentReserve = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType); } catch (e3) { currentReserve = 0; }

        local maxReserve = null;
        try { maxReserve = player.GetMaxAmmo(ammoType); } catch (eMax0) { maxReserve = null; }
        local weaponSpecificReserveCap = MercDeathDrops_GetWeaponSpecificReserveCap(player, weapon, className);
        if (weaponSpecificReserveCap != null && weaponSpecificReserveCap > 0)
        {
            if (maxReserve == null || maxReserve <= 0 || weaponSpecificReserveCap < maxReserve)
                maxReserve = weaponSpecificReserveCap;
        }
        if (maxReserve == null || maxReserve <= 0)
            maxReserve = cap;
        if (maxReserve == null || maxReserve <= 0)
            continue;

        local grant = ceil(maxReserve * packRatio);
        if (grant < 1)
            grant = 1;
        local newReserve = currentReserve + grant;
        if (newReserve > maxReserve)
            newReserve = maxReserve;

        if (newReserve > currentReserve)
        {
            try { NetProps.SetPropIntArray(player, "m_iAmmo", newReserve, ammoType); } catch (e4) {}
            gaveAny = true;
        }
    }

    return gaveAny;
}
getroottable()["MercDeathDrops_GiveAmmoMedium"] <- MercDeathDrops_GiveAmmoMedium;

function MercDeathDrops_GiveWeaponDrop(player, entry)
{
    if (!("GivePlayerWeapon" in getroottable()))
        return false;
    if (entry.giveClass == null || entry.giveClass == "")
        return false;
    if (entry.itemDefId < 0)
        return false;
    if (MercDeathDrops_PlayerHasWeapon(player, entry.itemDefId, entry.giveClass))
        return false;

    local previousWeapon = MercDeathDrops_GetWeaponInSlot(player, ("slotIndex" in entry) ? entry.slotIndex : -1);
    local previousDropInfo = MercDeathDrops_BuildDropInfoFromWeaponEntity(previousWeapon);
    local previousItemDefId = -1;
    if (previousWeapon != null)
    {
        try { previousItemDefId = NetProps.GetPropInt(previousWeapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex"); } catch (eItem0) { previousItemDefId = -1; }
        if (previousItemDefId < 0)
            try { previousItemDefId = NetProps.GetPropInt(previousWeapon, "m_iItemDefinitionIndex"); } catch (eItem1) { previousItemDefId = -1; }
    }

    if (previousWeapon != null && ("slotIndex" in entry) && entry.slotIndex == 2 && previousItemDefId != entry.itemDefId)
    {
        MercDeathDrops_RemoveWeaponEntityFromPlayer(player, previousWeapon);
        previousWeapon = null;
    }

    local weapon = GivePlayerWeapon(player, entry.giveClass, entry.itemDefId);
    if (weapon == null && previousWeapon != null)
    {
        MercDeathDrops_RemoveWeaponEntityFromPlayer(player, previousWeapon);
        weapon = GivePlayerWeapon(player, entry.giveClass, entry.itemDefId);
    }
    if (weapon == null)
        return false;

    try { MercDeathDrops_ApplyMercMeleePenalty(weapon, entry.itemDefId, entry.giveClass); } catch (ePenalty0) {}

    try
    {
        if ("ApplyWeaponAmmoDefaults" in getroottable())
            ApplyWeaponAmmoDefaults(player, weapon, entry.giveClass);
    }
    catch (e0) {}

    if (previousDropInfo != null)
    {
        local newItemDefId = -1;
        try { newItemDefId = entry.itemDefId; } catch (e1) { newItemDefId = -1; }
        if (previousDropInfo.itemDefId != newItemDefId)
        {
            try { MercDeathDrops_SpawnWeaponDropForPlayer(player, previousDropInfo, MERC_DROP_SWAP_PICKUP_DELAY); } catch (e2) {}
        }
    }

    local pickedUpItemDefId = -1;
    try { pickedUpItemDefId = entry.itemDefId; } catch (eVoice0) { pickedUpItemDefId = -1; }
    MercDeathDrops_MaybePlayAutograbVoice(player, pickedUpItemDefId);

    return true;
}

function MercDeathDrops_IsUsePressed(player)
{
    if (!("NetProps" in getroottable()))
        return false;
    local buttons = 0;
    try { buttons = NetProps.GetPropInt(player, "m_nButtons"); } catch (e0) { buttons = 0; }
    return ((buttons & IN_USE) != 0);
}

function MercDeathDrops_Update()
{
    local now = 0.0;
    try { now = Time(); } catch (e0) { now = 0.0; }
    local namesToRemove = [];

    foreach (name, entry in ::MercDeathDrops_Entries)
    {
        local prop = entry.prop;
        if (prop == null)
        {
            local glowMissing = ("glow" in entry) ? entry.glow : null;
            if (glowMissing != null)
                try { if (glowMissing.IsValid()) glowMissing.Kill(); } catch (eGlowMissing) {}
            namesToRemove.append(name);
            continue;
        }

        local valid = false;
        try { valid = prop.IsValid(); } catch (e1) { valid = false; }
        if (!valid)
        {
            local glowInvalid = ("glow" in entry) ? entry.glow : null;
            if (glowInvalid != null)
                try { if (glowInvalid.IsValid()) glowInvalid.Kill(); } catch (eGlowInvalid) {}
            namesToRemove.append(name);
            continue;
        }

        if (now >= entry.expireAt)
        {
            local glowExpire = ("glow" in entry) ? entry.glow : null;
            if (glowExpire != null)
                MercDeathDrops_RemoveManagedEntity(glowExpire);
            MercDeathDrops_RemoveManagedEntity(prop);
            namesToRemove.append(name);
            continue;
        }

        local desiredGlowColor = MERC_DROP_GLOW_COLOR_TOUCH;
        local shouldEnableGlow = false;

        if (now < entry.pickupAt)
        {
            if (entry.kind == "weapon")
                MercDeathDrops_SetGlowEnabled(entry, false);
            continue;
        }

        local propOrigin = prop.GetOrigin();
        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!MercDeathDrops_IsPlayablePlayer(player))
                continue;

            local playerEntIndex = -1;
            try { playerEntIndex = player.entindex(); } catch (ePlayerIdx) { playerEntIndex = -1; }
            if ("ownerEntIndex" in entry && "ownerBlockUntil" in entry)
            {
                if (playerEntIndex == entry.ownerEntIndex && now < entry.ownerBlockUntil)
                    continue;
            }

            local delta = player.GetOrigin() - propOrigin;
            local horizontalDistSqr = (delta.x * delta.x) + (delta.y * delta.y);
            if (horizontalDistSqr > MercDeathDrops_GetTouchRadiusSqrForEntry(entry))
                continue;
            if (fabs(delta.z) > MERC_DROP_TOUCH_Z_TOLERANCE)
                continue;

            if (entry.kind == "weapon")
            {
                local slotWeapon = MercDeathDrops_GetWeaponInSlot(player, ("slotIndex" in entry) ? entry.slotIndex : -1);
                if (MercDeathDrops_RequiresUseToPickup(player, entry))
                {
                    shouldEnableGlow = MERC_DROP_ENABLE_TOUCH_GLOW;
                    if (!MercDeathDrops_IsUsePressed(player))
                    {
                        MercDeathDrops_ShowUsePrompt(player, entry, slotWeapon);
                        if (MERC_DROP_ENABLE_TOUCH_GLOW)
                        {
                            MercDeathDrops_SetGlowEnabled(entry, true);
                            MercDeathDrops_SetGlowColor(entry, desiredGlowColor);
                        }
                        continue;
                    }
                    MercDeathDrops_ClearUsePromptCooldown(player);
                }
                if (MercDeathDrops_GiveWeaponDrop(player, entry))
                {
                    local glowPickup = ("glow" in entry) ? entry.glow : null;
                    if (glowPickup != null)
                        MercDeathDrops_RemoveManagedEntity(glowPickup);
                    MercDeathDrops_PlaySound(MERC_DROP_PICKUP_SOUND, prop);
                    MercDeathDrops_RemoveManagedEntity(prop);
                    namesToRemove.append(name);
                }
            }
            else if (entry.kind == "ammo")
            {
                if (MercDeathDrops_GiveAmmoMedium(player))
                {
                    MercDeathDrops_PlaySound(MERC_DROP_PICKUP_SOUND, prop);
                    MercDeathDrops_RemoveManagedEntity(prop);
                    namesToRemove.append(name);
                }
            }
            break;
        }

        if (entry.kind == "weapon")
        {
            MercDeathDrops_SetGlowEnabled(entry, shouldEnableGlow);
            if (shouldEnableGlow)
                MercDeathDrops_SetGlowColor(entry, desiredGlowColor);
        }
    }

    foreach (name in namesToRemove)
    {
        if (name in ::MercDeathDrops_Entries)
            delete ::MercDeathDrops_Entries[name];
    }
}

function MercDeathDrops_IsManagedEntity(ent)
{
    if (ent == null)
        return false;

    foreach (_name, entry in ::MercDeathDrops_Entries)
    {
        if (!("prop" in entry))
            continue;

        local prop = entry.prop;
        if (prop == null)
            continue;

        try
        {
            if (prop == ent)
                return true;
        }
        catch (e0) {}
    }

    return false;
}

getroottable()["MercDeathDrops_Tick"] <- function(hostEnt, serial)
{
    if (serial != ::MercDeathDrops_ThinkSerial)
        return;

    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        runtimeHost = ::MercDeathDrops_RuntimeHost;

    try { MercDeathDrops_Update(); } catch (e0) {}

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        local code = format("try{ MercDeathDrops_Tick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_DROP_THINK_INTERVAL, null, null); } catch (e1) {}
    }
}

function MercDeathDrops_StartThink(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        return;

    ::MercDeathDrops_RuntimeHost = runtimeHost;
    ::MercDeathDrops_ThinkSerial += 1;
    local serial = ::MercDeathDrops_ThinkSerial;

    try
    {
        runtimeHost.SetContextThink("MercDeathDropsThink", function()
        {
            try { MercDeathDrops_Update(); } catch (e0) {}
            return MERC_DROP_THINK_INTERVAL;
        }, MERC_DROP_THINK_INTERVAL);
    }
    catch (e1) {}

    local code = format("try{ MercDeathDrops_Tick(self, %d); }catch(e){}", serial);
    try { EntFireByHandle(runtimeHost, "RunScriptCode", code, MERC_DROP_THINK_INTERVAL, null, null); } catch (e2) {}
}

getroottable()["MercDeathDrops_CleanupNativeDroppedWeapons"] <- function()
{
    local classnames = [ "tf_ammo_pack", "tf_dropped_weapon", "tf_dropped_weapon_maker" ];
    foreach (classname in classnames)
    {
        local dropped = null;
        while ((dropped = Entities.FindByClassname(dropped, classname)) != null)
        {
            local targetname = "";
            try { targetname = dropped.GetName(); } catch (eName) { targetname = ""; }
            if (targetname != null && targetname.find("merc_drop_") == 0)
                continue;
            if (MercDeathDrops_IsManagedEntity(dropped))
                continue;

            try { dropped.Kill(); } catch (e0) {}
            try { dropped.Destroy(); } catch (e1) {}
            try { EntFireByHandle(dropped, "Kill", "", 0.0, null, null); } catch (e2) {}
        }
    }
}

getroottable()["MercDeathDrops_ScheduleNativeDropCleanup"] <- function(runtimeHost)
{
    if (runtimeHost == null || !runtimeHost.IsValid())
        return;

    local delays = [ 0.0, 0.05, 0.15, 0.35, 0.75 ];
    foreach (delay in delays)
    {
        try { EntFireByHandle(runtimeHost, "RunScriptCode", "try{ MercDeathDrops_CleanupNativeDroppedWeapons(); }catch(e){}", delay, null, null); } catch (e0) {}
    }
}

getroottable()["MercDeathDrops_OnPlayerDeath"] <- function(player)
{
    if (!MercDeathDrops_IsPlayablePlayer(player))
        return;
    if ("__Merc_DeathDropsEnabled" in getroottable())
    {
        if (!__Merc_DeathDropsEnabled())
            return;
    }

    local runtimeHost = ::MercDeathDrops_RuntimeHost;
    if (runtimeHost != null && runtimeHost.IsValid())
    {
        try { MercDeathDrops_ScheduleNativeDropCleanup(runtimeHost); } catch (eCleanup) {}
    }

    local origin = player.GetOrigin();
    local dropId = ::MercDeathDrops_NextId;
    ::MercDeathDrops_NextId += 1;
    local teamSkin = MercDeathDrops_GetTeamSkinIndex(player);

    if (__Merc_AmmoPacksEnabled())
    {
        local ammoProp = MercDeathDrops_SpawnPhysicsProp(
            format("merc_drop_ammo_%d", dropId),
            MERC_DROP_AMMO_MODEL,
            origin,
            teamSkin
        );
        if (ammoProp != null)
        {
            local ownerEntIndex = -1;
            try { ownerEntIndex = player.entindex(); } catch (eAmmoOwner) { ownerEntIndex = -1; }
            MercDeathDrops_RecordDrop("ammo", ammoProp, -1, null, MERC_DROP_PICKUP_DELAY, ownerEntIndex, -1);
        }
    }

    local activeWeapon = MercDeathDrops_GetActiveWeapon(player);
    local dropInfo = MercDeathDrops_BuildDropInfoFromWeaponEntity(activeWeapon);
    if (dropInfo == null)
        return;

    local weaponProp = MercDeathDrops_SpawnPhysicsProp(
        format("merc_drop_weapon_%d", dropId),
        dropInfo.worldModel,
        origin,
        teamSkin
    );
    if (weaponProp != null)
    {
        local ownerEntIndex = -1;
        try { ownerEntIndex = player.entindex(); } catch (eWeaponOwner) { ownerEntIndex = -1; }
        local effectivePickupDelay = MERC_DROP_PICKUP_DELAY;
        if (__Merc_DropWeaponsUseEnabled() && effectivePickupDelay > 0.65)
            effectivePickupDelay = 0.65;
        MercDeathDrops_RecordDrop("weapon", weaponProp, dropInfo.itemDefId, dropInfo.giveClass, effectivePickupDelay, ownerEntIndex, ("slotIndex" in dropInfo) ? dropInfo.slotIndex : -1);
    }
}

getroottable()["MercDeathDrops_Init"] <- function(hostEnt)
{
    local runtimeHost = hostEnt;
    if (runtimeHost == null)
    {
        try { runtimeHost = Entities.FindByClassname(null, "logic_script"); } catch (e0) { runtimeHost = null; }
        if (runtimeHost == null)
            try { runtimeHost = Entities.FindByClassname(null, "worldspawn"); } catch (e1) { runtimeHost = null; }
    }

    ::MercDeathDrops_RuntimeHost = runtimeHost;
    try { __IncludeScriptOnce("tf2c_dmrando.nut"); } catch (eDM) {}

    try { PrecacheModel(MERC_DROP_AMMO_MODEL); } catch (e2) {}
    foreach (itemDefId, modelPath in ::MercDeathDrops_ModelOverrides)
    {
        try { PrecacheModel(modelPath); } catch (e3) {}
    }
    try { PrecacheSound(MERC_DROP_PICKUP_SOUND); } catch (e4) {}
    try { PrecacheSound(MERC_DROP_USE_PROMPT_SOUND); } catch (e4a) {}
    foreach (snd in ::MercDeathDrops_AutograbVoices)
        try { PrecacheSound(snd); } catch (e5) {}
    foreach (snd in ::MercDeathDrops_TwinBarrelPickupVoices)
        try { PrecacheSound(snd); } catch (e6) {}
    foreach (snd in ::MercDeathDrops_AAGunPickupVoices)
        try { PrecacheSound(snd); } catch (e7) {}

    if (runtimeHost != null && runtimeHost.IsValid())
        MercDeathDrops_StartThink(runtimeHost);
}
