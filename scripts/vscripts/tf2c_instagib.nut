// tf2c_instagib.nut
// Merc DM instagib module:
// - Intended to be used by tf2c_merc_soldieronly.nut
// - Gives Sniper Rifle + Shovel to humans, Huntsman + Shovel to bots (no secondary)
// - Applies high damage multiplier to the granted primary + shovel instead of script-forced kills

if (!("TF2C_Instagib_EventsRegistered" in getroottable()))
    ::TF2C_Instagib_EventsRegistered <- false;
if (!("TF2C_Instagib_Host" in getroottable()))
    ::TF2C_Instagib_Host <- null;

const TF2C_INSTAGIB_ITEMDEF_SNIPERRIFLE = 14;
const TF2C_INSTAGIB_ITEMDEF_HUNTSMAN = 52;
const TF2C_INSTAGIB_ITEMDEF_SHOVEL = 6;
const TF2C_INSTAGIB_DAMAGE_MULT = 10.0;
const TF2C_INSTAGIB_SHOVEL_HEALTH_PENALTY = -50;
const TF2C_INSTAGIB_DEATH_SNDLVL = 70;
::TF2C_Instagib_DeathSounds <- ["player/gibexplosion1.wav", "player/gibexplosion2.wav", "player/gibexplosion3.wav"];

function TF2C_Instagib_IsEnabled()
{
    local gamemode = 0;

    if ("Convars" in getroottable())
    {
        try { gamemode = Convars.GetInt("tf2c_dm_gamemode"); } catch (e0) { gamemode = 0; }
    }

    return (gamemode == 2);
}

function TF2C_Instagib_IsPlayablePlayer(player)
{
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return false;

    local team = 0;
    try { team = player.GetTeam(); } catch (e0) { team = 0; }
    return (team >= 2);
}

function TF2C_Instagib_IsBotPlayer(player)
{
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return false;

    try
    {
        if ("IsFakeClient" in player)
            return player.IsFakeClient();
    }
    catch (e0) {}

    if ("NetProps" in getroottable())
    {
        try
        {
            if (NetProps.GetPropBool(player, "m_bIsABot"))
                return true;
        }
        catch (e1) {}
    }

    return false;
}

function TF2C_Instagib_EnsureGiveWeaponSupport()
{
    if ("GivePlayerWeapon" in getroottable())
        return;

    // Keep instagib isolated: only use the lightweight weapon spawner helper.
    try { if ("DoIncludeScript" in getroottable()) DoIncludeScript("tf2c_weaponspawners.nut", getroottable()); } catch (e0) {}
}

function TF2C_Instagib_ApplyWeaponAttributes(weapon, isShovel = false)
{
    if (weapon == null || !weapon.IsValid())
        return;

    try
    {
        if ("AddAttribute" in weapon)
            weapon.AddAttribute("damage bonus", TF2C_INSTAGIB_DAMAGE_MULT, -1);
    }
    catch (e0) {}

    if (!isShovel)
        return;

    try
    {
        if ("AddAttribute" in weapon)
        {
            weapon.AddAttribute("max health additive penalty", TF2C_INSTAGIB_SHOVEL_HEALTH_PENALTY, -1);
            local shouldGrantNoFall = true;
            if ("__Merc_ShouldGrantNoFallDamage" in getroottable())
                shouldGrantNoFall = __Merc_ShouldGrantNoFallDamage();
            if (shouldGrantNoFall)
                weapon.AddAttribute("cancel falling damage", 1, -1);
        }
    }
    catch (e1) {}
}

function TF2C_Instagib_RefreshFallDamageState(player)
{
    if (!TF2C_Instagib_IsPlayablePlayer(player))
        return

    local appliedShared = false
    try
    {
        if ("__Merc_RefreshFallDamageState" in getroottable())
        {
            __Merc_RefreshFallDamageState(player)
            appliedShared = true
        }
    }
    catch (e0) { appliedShared = false }

    if (appliedShared)
        return

    try
    {
        if ("RemoveCustomAttribute" in player)
            player.RemoveCustomAttribute("cancel falling damage")
    }
    catch (e1) {}

    try
    {
        local shouldGrantNoFall = true
        if ("__Merc_ShouldGrantNoFallDamage" in getroottable())
            shouldGrantNoFall = __Merc_ShouldGrantNoFallDamage()
        if ("AddCustomAttribute" in player && shouldGrantNoFall)
            player.AddCustomAttribute("cancel falling damage", 1, -1)
    }
    catch (e2) {}
}

function TF2C_Instagib_GiveLoadout(player)
{
    if (!TF2C_Instagib_IsPlayablePlayer(player))
        return false;

    TF2C_Instagib_EnsureGiveWeaponSupport();
    if (!("GivePlayerWeapon" in getroottable()))
        return false;

    local primary = null;
    local shovel = null;
    local primaryClass = "tf_weapon_sniperrifle";
    local primaryItemDef = TF2C_INSTAGIB_ITEMDEF_SNIPERRIFLE;

    if (TF2C_Instagib_IsBotPlayer(player))
    {
        primaryClass = "tf_weapon_compound_bow";
        primaryItemDef = TF2C_INSTAGIB_ITEMDEF_HUNTSMAN;
    }

    // Clear any stale melee entity before regranting the baseline shovel so
    // the shovel health penalty cannot stack across deaths.
    if ("StripWeaponSlot" in getroottable())
    {
        try { StripWeaponSlot(player, 2); } catch (eStrip0) {}
    }
    if ("NetProps" in getroottable())
    {
        for (local i = 0; i < 8; i++)
        {
            local held = null;
            try { held = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (eHeld0) { held = null; }
            if (held == null)
                continue;

            local heldSlot = -2;
            try { heldSlot = held.GetSlot(); } catch (eHeld1) { heldSlot = -2; }
            if (heldSlot != 2)
                continue;

            try { held.Destroy(); } catch (eHeld2) { try { held.Kill(); } catch (eHeld3) {} }
            try { NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); } catch (eHeld4) {}
        }
    }

    // No secondary by design.
    try { primary = GivePlayerWeapon(player, primaryClass, primaryItemDef); } catch (e0) { primary = null; }
    try { shovel = GivePlayerWeapon(player, "tf_weapon_shovel", TF2C_INSTAGIB_ITEMDEF_SHOVEL); } catch (e1) { shovel = null; }

    try { TF2C_Instagib_ApplyWeaponAttributes(primary, false); } catch (eAttr0) {}
    try { TF2C_Instagib_ApplyWeaponAttributes(shovel, true); } catch (eAttr1) {}
    try { TF2C_Instagib_RefreshFallDamageState(player); } catch (eAttr2) {}

    try
    {
        if (primary != null)
            player.Weapon_Switch(primary);
        else if (shovel != null)
            player.Weapon_Switch(shovel);
    }
    catch (e2) {}

    return (primary != null || shovel != null);
}

function TF2C_Instagib_ScheduleLoadoutRefresh(player, delay, suffix)
{
    if (!TF2C_Instagib_IsPlayablePlayer(player))
        return;

    local entIdx = -1;
    try { entIdx = player.entindex(); } catch (e0) { entIdx = -1; }
    if (entIdx < 0)
        return;

    try
    {
        player.SetContextThink("TF2C_Instagib_Reapply_" + entIdx + "_" + suffix, function()
        {
            try { TF2C_Instagib_GiveLoadout(player); } catch (e1) {}
            try
            {
                if ("__Merc_ScheduleFallDamageRefresh" in getroottable())
                {
                    __Merc_ScheduleFallDamageRefresh(player, 0.00, "instagib_" + suffix + "_a");
                    __Merc_ScheduleFallDamageRefresh(player, 0.10, "instagib_" + suffix + "_b");
                }
                TF2C_Instagib_RefreshFallDamageState(player);
            }
            catch (e2) {}
            return null;
        }, delay);
    }
    catch (e3) {}
}

function TF2C_Instagib_PlayDeathFx(victim)
{
    if (!TF2C_Instagib_IsPlayablePlayer(victim))
        return;

    local pos = Vector(0, 0, 0);
    try { pos = victim.GetOrigin(); } catch (eP0) {}

    // Blood splatter particle at victim location.
    try
    {
        local fx = SpawnEntityFromTable("info_particle_system",
        {
            effect_name = "blood_trail_red_01_splatter",
            start_active = "0"
        });
        if (fx != null)
        {
            try { fx.SetAbsOrigin(pos); } catch (eP1) {}
            try { EntFireByHandle(fx, "Start", "", 0.0, null, null); } catch (eP2) {}
            try { EntFireByHandle(fx, "Kill", "", 1.5, null, null); } catch (eP3) {}
        }
    }
    catch (eP4) {}

    // Random gib explosion sound, short audible range.
    local snd = "player/gibexplosion1.wav";
    try
    {
        local idx = RandomInt(0, ::TF2C_Instagib_DeathSounds.len() - 1);
        snd = ::TF2C_Instagib_DeathSounds[idx];
    }
    catch (eS0) {}

    try
    {
        local params =
        {
            sound_name = snd,
            entity = victim,
            speakerentity = victim.entindex(),
            origin = pos,
            volume = 0.75,
            pitch = 100,
            soundlevel = TF2C_INSTAGIB_DEATH_SNDLVL
        };
        EmitSoundEx(params);
        return;
    }
    catch (eS1) {}

    try { EmitSoundOn(snd, victim); } catch (eS2) {}
}

function TF2C_Instagib_OnPlayerDeath(params)
{
    if (!TF2C_Instagib_IsEnabled())
        return;
    if (params == null || !("userid" in params))
        return;

    local victim = null;
    try { victim = GetPlayerFromUserID(params.userid); } catch (e0) { victim = null; }
    if (!TF2C_Instagib_IsPlayablePlayer(victim))
        return;

    TF2C_Instagib_PlayDeathFx(victim);
}

function TF2C_Instagib_OnPostInventoryApplication(params)
{
    if (!TF2C_Instagib_IsEnabled())
        return;
    if (params == null || !("userid" in params))
        return;

    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    if (!TF2C_Instagib_IsPlayablePlayer(player))
        return;

    TF2C_Instagib_ScheduleLoadoutRefresh(player, 0.00, "pia0");
    TF2C_Instagib_ScheduleLoadoutRefresh(player, 0.05, "pia1");
    TF2C_Instagib_ScheduleLoadoutRefresh(player, 0.15, "pia2");
}

function TF2C_Instagib_Init(hostEnt = null)
{
    if (hostEnt != null)
        ::TF2C_Instagib_Host = hostEnt;

    if (::TF2C_Instagib_EventsRegistered)
        return;

    if (!("ListenToGameEvent" in getroottable()))
        return;

    local ok = false;
    try
    {
        ListenToGameEvent("player_death", TF2C_Instagib_OnPlayerDeath, "");
        ListenToGameEvent("post_inventory_application", TF2C_Instagib_OnPostInventoryApplication, "");
        ok = true;
    }
    catch (e0)
    {
        try
        {
            ListenToGameEvent("player_death", "TF2C_Instagib_OnPlayerDeath", "");
            ListenToGameEvent("post_inventory_application", "TF2C_Instagib_OnPostInventoryApplication", "");
            ok = true;
        }
        catch (e1) { ok = false; }
    }

    ::TF2C_Instagib_EventsRegistered = ok;

    try { if ("PrecacheParticleSystem" in getroottable()) PrecacheParticleSystem("blood_trail_red_01_splatter"); } catch (eP5) {}
    try { PrecacheSound("player/gibexplosion1.wav"); } catch (eS3) {}
    try { PrecacheSound("player/gibexplosion2.wav"); } catch (eS4) {}
    try { PrecacheSound("player/gibexplosion3.wav"); } catch (eS5) {}
}

getroottable()["TF2C_Instagib_IsEnabled"] <- TF2C_Instagib_IsEnabled;
getroottable()["TF2C_Instagib_GiveLoadout"] <- TF2C_Instagib_GiveLoadout;
getroottable()["TF2C_Instagib_OnPlayerDeath"] <- TF2C_Instagib_OnPlayerDeath;
getroottable()["TF2C_Instagib_OnPostInventoryApplication"] <- TF2C_Instagib_OnPostInventoryApplication;
getroottable()["TF2C_Instagib_Init"] <- TF2C_Instagib_Init;
