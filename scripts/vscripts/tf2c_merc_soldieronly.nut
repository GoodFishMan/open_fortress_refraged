// IMPORTANT:
// This script is often re-fired on real round restarts (e.g. WaitingForPlayers ending).
// Round restarts can reset entities and wipe runtime AddOutput hooks (like the pill overheal fix).
// So even if we've already defined all functions, we must still run "runtime init" again.
getroottable()["TF2C_MercSoldierOnly_RuntimeInit"] <- function(hostEnt)
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

    // Overheal (pill) idle fix hooker (rehook on each re-fire)
    try
    {
        if (!("g_includedOverhealIdleFix" in getroottable())) ::g_includedOverhealIdleFix <- false;
        if (!::g_includedOverhealIdleFix)
            ::g_includedOverhealIdleFix <- __IncludeScriptSafe("tf2c_overheal_idlefix.nut", getroottable());

        if ("OverhealIdleFix_Init" in getroottable())
        {
            try { OverhealIdleFix_Init(runtimeHost); } catch (e2) {}
            // Late re-init to survive entity reset ordering during round restart
            try
            {
                if (runtimeHost != null && runtimeHost.IsValid())
                    EntFireByHandle(runtimeHost, "RunScriptCode", "try{ OverhealIdleFix_Init(self); }catch(e){}", 1.5, null, null);
            }
            catch (e3) {}
            try
            {
                if (runtimeHost != null && runtimeHost.IsValid())
                    EntFireByHandle(runtimeHost, "RunScriptCode", "try{ OverhealIdleFix_Init(self); }catch(e){}", 3.0, null, null);
            }
            catch (e4) {}
        }
    }
    catch (e) {}

    try
    {
        if (!("__g_includedTempPowerups" in getroottable())) ::__g_includedTempPowerups <- false;
        if (!::__g_includedTempPowerups)
            ::__g_includedTempPowerups <- __IncludeScriptSafe("tf2c_temp_powerups.nut", getroottable());

        if ("MercTempPowerups_Init" in getroottable())
        {
            try { MercTempPowerups_Init(runtimeHost); } catch (eTP0) {}
            try
            {
                if (runtimeHost != null && runtimeHost.IsValid())
                    EntFireByHandle(runtimeHost, "RunScriptCode", "try{ MercTempPowerups_Init(self); }catch(e){}", 1.5, null, null);
            }
            catch (eTP1) {}
            try
            {
                if (runtimeHost != null && runtimeHost.IsValid())
                    EntFireByHandle(runtimeHost, "RunScriptCode", "try{ MercTempPowerups_Init(self); }catch(e){}", 3.0, null, null);
            }
            catch (eTP2) {}
        }
    }
    catch (eTP) {}

}

if (!("TF2C_MercSoldierOnly_Initialized" in getroottable()))
    ::TF2C_MercSoldierOnly_Initialized <- false;
if (!("TF2C_MercSoldierOnly_EventsRegistered" in getroottable()))
    ::TF2C_MercSoldierOnly_EventsRegistered <- false;

::TF2C_MercSoldierOnly_Initialized <- true;

// tf2c_merc_soldieronly.nut (base)
// Enforces Soldier + Merc DM model, but ONLY when player is on a real team (team index >= 2).
// If ::randomizerEnabled == 0: strips weapons, gives Engineer pistol + Shovel.
// If ::randomizerEnabled == 1: delegates weapons to tf2c_dmrando.nut (separate file).

::randomizerEnabled <- 1; // 1 = enabled (default), 0 = disabled
::debugLoadoutPrint <- 1; // 1 = print what weapons were given
::g_MercLastLoadoutTime <- {};      // entindex -> last Time() we randomized weapons
::g_MercLastRespawnFxTime <- {};    // entindex -> last Time() we played respawn particle
::g_MercLastRespawnVoiceTime <- {}; // entindex -> last Time() we played respawn voice line
::g_MercLastGlobalRespawnVoiceTime <- 0.0;
::g_includedRespawnParticles <- false;
::g_MercRuntimeHost <- null;
::g_MercSpeedThinkSerial <- 0;


// ---- constants ----
const TF_CLASS_SOLDIER = 3;
const MERC_MODEL = "models/player/mercenary.mdl";
const MERC_MEDIC_SPEED_MULT = 1
const MERC_ENABLE_SPEED_ADJUSTMENTS = false
::MERC_GIB_MODELS <- [
    "models/player/gibs/mercdeathmatchgib001.mdl",
    "models/player/gibs/mercdeathmatchgib002.mdl",
    "models/player/gibs/mercdeathmatchgib003.mdl",
    "models/player/gibs/mercdeathmatchgib004.mdl",
    "models/player/gibs/mercdeathmatchgib005.mdl",
    "models/player/gibs/mercdeathmatchgib006.mdl",
    "models/player/gibs/mercdeathmatchgib007.mdl",
    "models/player/gibs/mercdeathmatchgib008.mdl"
]


// Jump VO
const MERC_JUMP_SOUND_PREFIX = "vo/mercenary_jump0"
const MERC_JUMP_SOUND_SUFFIX = ".mp3"
const MERC_JUMP_SOUND_COUNT  = 3
const MERC_LOCAL_SNDLVL = 70
const MERC_RESPAWN_VOICE_PREFIX = "vo/customclass/mercenary/mercenary_respawn"
const MERC_RESPAWN_VOICE_SUFFIX = ".mp3"
const MERC_RESPAWN_VOICE_COUNT  = 20
const MERC_RESPAWN_VOICE_VOLUME = 0.65
const MERC_RESPAWN_VOICE_COOLDOWN = 15.0
const MERC_RESPAWN_VOICE_MIN_SCRIPT_AGE = 35.0
const MERC_CVAR_JUMPSOUNDS = "tf2c_dm_jumpsounds"
const MERC_CVAR_SPAWNPROTECT = "tf2c_dm_spawnprotect"
const MERC_CVAR_DISABLE_RESPAWN_TIMES = "tf2c_dm_disablerespawntimes"
const MERC_CVAR_PLAYERGIB = "tf2c_dm_playergib"
const MERC_CVAR_AUTOJUMP = "tf2c_dm_autojump"
const MERC_CVAR_DUCKJUMP = "tf2c_dm_duckjump"
const MERC_CVAR_AIRACCELERATE = "tf2c_dm_airaccelerate"
const MERC_CVAR_BHOP_MAX_SPEED_FACTOR = "tf2c_dm_bunnyjump_max_speed_factor"
const MERC_CVAR_GROUNDSPEED_CAP = "tf2c_dm_groundspeed_cap"
const MERC_CVAR_GAMEMODE = "tf2c_dm_gamemode"
const MERC_CVAR_FRAGLIMIT = "tf2c_dm_fraglimit"
const MERC_CVAR_AMMOPACKS = "tf2c_dm_ammopacks"
const MERC_CVAR_DROPWEAPONS_USE = "tf2c_dm_dropweapons_use"
const MERC_CVAR_DROPWEAPONS_ENABLE = "tf2c_dm_dropweapons_enable"
const MERC_CVAR_DROPPED_WEAPON_DESPAWNTIME = "tf2c_dm_dropped_weapon_despawntime"
const MERC_CVAR_DROPPED_AMMOBOX_DESPAWNTIME = "tf2c_dm_dropped_ammobox_despawntime"
const MERC_CVAR_WEAPONSPAWNERS_USE = "tf2c_dm_weaponspawners_use"
const MERC_CVAR_WEAPONSPAWNERS_REPLACE_PISTOL = "tf2c_dm_weaponspawners_replace_pistol"
const MERC_CVAR_WEAPONSTAY = "tf2c_dm_weaponstay"
const MERC_CVAR_BOT_BOTLOADOUTS = "tf2c_dm_botloadouts"
const MERC_CVAR_FALLDAMAGE = "tf2c_dm_falldamage"
const MERC_CVAR_GG_BOTS_SKIP_SNIPER = "tf2c_dm_gg_botsskipsniper"
const TF_COND_UBERCHARGED = 5
// Anti-loop guard for forced class regen
::g_forceClassLastTime <- {};

// Include guards
::g_includedDMRando <- false;
::g_includedInstagib <- false;
::g_includedArmsRace <- false;
::g_includedOverhealIdleFix <- false;
::g_MercLastSpawnProtectTime <- {};
::g_MercScriptStartTime <- null;

// ---- safe include ----
function __IncludeScriptSafe(scriptName, scopeTable)
{
	// Some TF2C builds have DoIncludeScript(script, scope), others may have 1-arg.
	// Try in decreasing specificity; swallow failures.
	try
	{
		if ("DoIncludeScript" in getroottable())
		{
			// Try 2-arg first
			try { DoIncludeScript(scriptName, scopeTable); return true; } catch (e2) {}
			// Try 1-arg
			try { DoIncludeScript(scriptName); return true; } catch (e1) {}
		}

		if ("IncludeScript" in getroottable())
		{
			// IncludeScript typically takes (name, scope) but some take 1 arg.
			try { IncludeScript(scriptName, scopeTable); return true; } catch (e4) {}
			try { IncludeScript(scriptName); return true; } catch (e3) {}
		}
	}
	catch (e) {}

	return false;
}

// Jump VO
// ---------------------------------------------------------------------------

function __Merc_RegisterConVars()
{
    local rt = getroottable()
    if (!("__mercConvarsReady" in rt)) rt.__mercConvarsReady <- false
    if (!("__mercJumpSoundsDefault" in rt)) rt.__mercJumpSoundsDefault <- 1
    if (!("__mercSpawnProtectDefault" in rt)) rt.__mercSpawnProtectDefault <- 3.0
    if (!("__mercDisableRespawnTimesDefault" in rt)) rt.__mercDisableRespawnTimesDefault <- 1
    if (!("__mercPlayerGibDefault" in rt)) rt.__mercPlayerGibDefault <- 0
    if (!("__mercAutojumpDefault" in rt)) rt.__mercAutojumpDefault <- 1
    if (!("__mercDuckjumpDefault" in rt)) rt.__mercDuckjumpDefault <- 1
    if (!("__mercAiraccelerateDefault" in rt)) rt.__mercAiraccelerateDefault <- 50.0
    if (!("__mercBhopMaxSpeedFactorDefault" in rt)) rt.__mercBhopMaxSpeedFactorDefault <- -1.0
    if (!("__mercGroundspeedCapDefault" in rt)) rt.__mercGroundspeedCapDefault <- -1.0
    if (!("__mercFraglimitDefault" in rt)) rt.__mercFraglimitDefault <- -1.0
    if (!("__mercGamemodeDefault" in rt)) rt.__mercGamemodeDefault <- 1
    if (!("__mercAmmoPacksDefault" in rt)) rt.__mercAmmoPacksDefault <- 1
    if (!("__mercDropWeaponsUseDefault" in rt)) rt.__mercDropWeaponsUseDefault <- 1
    if (!("__mercDropWeaponsEnableDefault" in rt)) rt.__mercDropWeaponsEnableDefault <- 1
    if (!("__mercWeaponSpawnersUseDefault" in rt)) rt.__mercWeaponSpawnersUseDefault <- 1
    if (!("__mercWeaponSpawnersReplacePistolDefault" in rt)) rt.__mercWeaponSpawnersReplacePistolDefault <- 0
    if (!("__mercWeaponStayDefault" in rt)) rt.__mercWeaponStayDefault <- 0
    if (!("__mercBotBotLoadoutsDefault" in rt)) rt.__mercBotBotLoadoutsDefault <- 1
    if (!("__mercFallDamageDefault" in rt)) rt.__mercFallDamageDefault <- 0
    if (!("__mercGGBotsSkipSniperDefault" in rt)) rt.__mercGGBotsSkipSniperDefault <- 1
    if (!("__mercPreserveSourceLogicDefault" in rt)) rt.__mercPreserveSourceLogicDefault <- 0

    if (!("Convars" in rt))
        return

    // Always attempt registration when Convars is available.
    // This avoids stale "__mercConvarsReady" state after script updates adding new cvars.
    try { Convars.RegisterConvar(MERC_CVAR_JUMPSOUNDS, "1", "Enable Merc jump sounds (1=allow, 0=disable).", 0) } catch (e0) {}
    try { Convars.RegisterConvar(MERC_CVAR_JUMPSOUNDS, "1", "Enable Merc jump sounds (1=allow, 0=disable).") } catch (e1) {}
    try { Convars.RegisterConvar(MERC_CVAR_JUMPSOUNDS, 1, "Enable Merc jump sounds (1=allow, 0=disable).", 0) } catch (e2) {}

    try { Convars.RegisterConvar(MERC_CVAR_SPAWNPROTECT, "3", "Spawn protection Uber duration in seconds (0=disable).", 0) } catch (e3) {}
    try { Convars.RegisterConvar(MERC_CVAR_SPAWNPROTECT, "3", "Spawn protection Uber duration in seconds (0=disable).") } catch (e4) {}
    try { Convars.RegisterConvar(MERC_CVAR_SPAWNPROTECT, 3, "Spawn protection Uber duration in seconds (0=disable).", 0) } catch (e5) {}

    try { Convars.RegisterConvar(MERC_CVAR_DISABLE_RESPAWN_TIMES, "1", "Force mp_disable_respawn_times while script is active (1=on, 0=off).", 0) } catch (e6) {}
    try { Convars.RegisterConvar(MERC_CVAR_DISABLE_RESPAWN_TIMES, "1", "Force mp_disable_respawn_times while script is active (1=on, 0=off).") } catch (e7) {}
    try { Convars.RegisterConvar(MERC_CVAR_DISABLE_RESPAWN_TIMES, 1, "Force mp_disable_respawn_times while script is active (1=on, 0=off).", 0) } catch (e8) {}

    try { Convars.RegisterConvar(MERC_CVAR_PLAYERGIB, "0", "Force tf_playergib while script is active (0=off, 1=on).", 0) } catch (e9) {}
    try { Convars.RegisterConvar(MERC_CVAR_PLAYERGIB, "0", "Force tf_playergib while script is active (0=off, 1=on).") } catch (e10) {}
    try { Convars.RegisterConvar(MERC_CVAR_PLAYERGIB, 0, "Force tf_playergib while script is active (0=off, 1=on).", 0) } catch (e11) {}

    try { Convars.RegisterConvar(MERC_CVAR_AUTOJUMP, "1", "Force tf2c_autojump while script is active (1=on, 0=off).", 0) } catch (e12) {}
    try { Convars.RegisterConvar(MERC_CVAR_AUTOJUMP, "1", "Force tf2c_autojump while script is active (1=on, 0=off).") } catch (e13) {}
    try { Convars.RegisterConvar(MERC_CVAR_AUTOJUMP, 1, "Force tf2c_autojump while script is active (1=on, 0=off).", 0) } catch (e14) {}

    try { Convars.RegisterConvar(MERC_CVAR_DUCKJUMP, "1", "Force tf2c_duckjump while script is active (1=on, 0=off).", 0) } catch (e15) {}
    try { Convars.RegisterConvar(MERC_CVAR_DUCKJUMP, "1", "Force tf2c_duckjump while script is active (1=on, 0=off).") } catch (e16) {}
    try { Convars.RegisterConvar(MERC_CVAR_DUCKJUMP, 1, "Force tf2c_duckjump while script is active (1=on, 0=off).", 0) } catch (e17) {}

    try { Convars.RegisterConvar(MERC_CVAR_AIRACCELERATE, "50", "Force sv_airaccelerate while script is active.", 0) } catch (e18) {}
    try { Convars.RegisterConvar(MERC_CVAR_AIRACCELERATE, "50", "Force sv_airaccelerate while script is active.") } catch (e19) {}
    try { Convars.RegisterConvar(MERC_CVAR_AIRACCELERATE, 50, "Force sv_airaccelerate while script is active.", 0) } catch (e20) {}

    try { Convars.RegisterConvar(MERC_CVAR_BHOP_MAX_SPEED_FACTOR, "-1", "Force tf2c_bunnyjump_max_speed_factor while script is active.", 0) } catch (e21) {}
    try { Convars.RegisterConvar(MERC_CVAR_BHOP_MAX_SPEED_FACTOR, "-1", "Force tf2c_bunnyjump_max_speed_factor while script is active.") } catch (e22) {}
    try { Convars.RegisterConvar(MERC_CVAR_BHOP_MAX_SPEED_FACTOR, -1, "Force tf2c_bunnyjump_max_speed_factor while script is active.", 0) } catch (e23) {}

    try { Convars.RegisterConvar(MERC_CVAR_GROUNDSPEED_CAP, "-1", "Force tf2c_groundspeed_cap while script is active.", 0) } catch (e24) {}
    try { Convars.RegisterConvar(MERC_CVAR_GROUNDSPEED_CAP, "-1", "Force tf2c_groundspeed_cap while script is active.") } catch (e25) {}
    try { Convars.RegisterConvar(MERC_CVAR_GROUNDSPEED_CAP, -1, "Force tf2c_groundspeed_cap while script is active.", 0) } catch (e26) {}

    try { Convars.RegisterConvar(MERC_CVAR_FRAGLIMIT, "-1", "Override tf2c_domination_override_pointlimit (-1 keeps default game behavior).", 0) } catch (e27) {}
    try { Convars.RegisterConvar(MERC_CVAR_FRAGLIMIT, "-1", "Override tf2c_domination_override_pointlimit (-1 keeps default game behavior).") } catch (e28) {}
    try { Convars.RegisterConvar(MERC_CVAR_FRAGLIMIT, -1, "Override tf2c_domination_override_pointlimit (-1 keeps default game behavior).", 0) } catch (e29) {}

    try { Convars.RegisterConvar(MERC_CVAR_GAMEMODE, "0", "Merc DM mode: 0=Normal (pistol+shovel), 1=Randomizer, 2=Instagib, 3=Infection, 4=Arms Race.", 0) } catch (e30) {}
    try { Convars.RegisterConvar(MERC_CVAR_GAMEMODE, "0", "Merc DM mode: 0=Normal (pistol+shovel), 1=Randomizer, 2=Instagib, 3=Infection, 4=Arms Race.") } catch (e31) {}
    try { Convars.RegisterConvar(MERC_CVAR_GAMEMODE, 0, "Merc DM mode: 0=Normal (pistol+shovel), 1=Randomizer, 2=Instagib, 3=Infection, 4=Arms Race.", 0) } catch (e32) {}

    try { Convars.RegisterConvar(MERC_CVAR_AMMOPACKS, "1", "Drop medium ammo packs from players on death (1=on, 0=off).", 0) } catch (e33) {}
    try { Convars.RegisterConvar(MERC_CVAR_AMMOPACKS, "1", "Drop medium ammo packs from players on death (1=on, 0=off).") } catch (e34) {}
    try { Convars.RegisterConvar(MERC_CVAR_AMMOPACKS, 1, "Drop medium ammo packs from players on death (1=on, 0=off).", 0) } catch (e35) {}

    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_USE, "1", "Require +use to pick up dropped weapons (1=on, 0=touch pickup).", 0) } catch (e36) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_USE, "1", "Require +use to pick up dropped weapons (1=on, 0=touch pickup).") } catch (e37) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_USE, 1, "Require +use to pick up dropped weapons (1=on, 0=touch pickup).", 0) } catch (e38) {}

    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_ENABLE, "1", "Enable death-dropped weapons and ammo packs (1=on, 0=off).", 0) } catch (e39) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_ENABLE, "1", "Enable death-dropped weapons and ammo packs (1=on, 0=off).") } catch (e40) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPWEAPONS_ENABLE, 1, "Enable death-dropped weapons and ammo packs (1=on, 0=off).", 0) } catch (e41) {}

    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_WEAPON_DESPAWNTIME, "15", "Lifetime in seconds for Merc dropped weapons before despawn.", 0) } catch (e41a) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_WEAPON_DESPAWNTIME, "15", "Lifetime in seconds for Merc dropped weapons before despawn.") } catch (e41b) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_WEAPON_DESPAWNTIME, 15, "Lifetime in seconds for Merc dropped weapons before despawn.", 0) } catch (e41c) {}

    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_AMMOBOX_DESPAWNTIME, "15", "Lifetime in seconds for Merc dropped ammo boxes before despawn.", 0) } catch (e41d) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_AMMOBOX_DESPAWNTIME, "15", "Lifetime in seconds for Merc dropped ammo boxes before despawn.") } catch (e41e) {}
    try { Convars.RegisterConvar(MERC_CVAR_DROPPED_AMMOBOX_DESPAWNTIME, 15, "Lifetime in seconds for Merc dropped ammo boxes before despawn.", 0) } catch (e41f) {}

    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_USE, "1", "Require +use to switch to a weapon spawner pickup when the slot is already occupied (1=on, 0=touch pickup).", 0) } catch (e42) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_USE, "1", "Require +use to switch to a weapon spawner pickup when the slot is already occupied (1=on, 0=touch pickup).") } catch (e43) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_USE, 1, "Require +use to switch to a weapon spawner pickup when the slot is already occupied (1=on, 0=touch pickup).", 0) } catch (e44) {}

    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_REPLACE_PISTOL, "0", "Allow weapon pickups to replace pistol without +use when the target slot is secondary (1=on, 0=off).", 0) } catch (e44a) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_REPLACE_PISTOL, "0", "Allow weapon pickups to replace pistol without +use when the target slot is secondary (1=on, 0=off).") } catch (e44b) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSPAWNERS_REPLACE_PISTOL, 0, "Allow weapon pickups to replace pistol without +use when the target slot is secondary (1=on, 0=off).", 0) } catch (e44c) {}

    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSTAY, "0", "Weapon spawners respawn quickly and silently when enabled (1=0.5s weapon stay, 0=10s normal).", 0) } catch (e45) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSTAY, "0", "Weapon spawners respawn quickly and silently when enabled (1=0.5s weapon stay, 0=10s normal).") } catch (e46) {}
    try { Convars.RegisterConvar(MERC_CVAR_WEAPONSTAY, 0, "Weapon spawners respawn quickly and silently when enabled (1=0.5s weapon stay, 0=10s normal).", 0) } catch (e47) {}

    try { Convars.RegisterConvar(MERC_CVAR_BOT_BOTLOADOUTS, "1", "Give bots a delayed DM weapon loadout in normal Merc DM after warmup (1=on, 0=off).", 0) } catch (e48) {}
    try { Convars.RegisterConvar(MERC_CVAR_BOT_BOTLOADOUTS, "1", "Give bots a delayed DM weapon loadout in normal Merc DM after warmup (1=on, 0=off).") } catch (e49) {}
    try { Convars.RegisterConvar(MERC_CVAR_BOT_BOTLOADOUTS, 1, "Give bots a delayed DM weapon loadout in normal Merc DM after warmup (1=on, 0=off).", 0) } catch (e50) {}

    try { Convars.RegisterConvar(MERC_CVAR_FALLDAMAGE, "0", "Merc fall damage handling: 0=grant no-fall-damage attr on owned melee, 1=do not grant it.", 0) } catch (e51) {}
    try { Convars.RegisterConvar(MERC_CVAR_FALLDAMAGE, "0", "Merc fall damage handling: 0=grant no-fall-damage attr on owned melee, 1=do not grant it.") } catch (e52) {}
    try { Convars.RegisterConvar(MERC_CVAR_FALLDAMAGE, 0, "Merc fall damage handling: 0=grant no-fall-damage attr on owned melee, 1=do not grant it.", 0) } catch (e53) {}

    try { Convars.RegisterConvar(MERC_CVAR_GG_BOTS_SKIP_SNIPER, "1", "Arms Race: bots skip the Sniper Rifle rank and advance to the next weapon instead (1=on, 0=off).", 0) } catch (e54) {}
    try { Convars.RegisterConvar(MERC_CVAR_GG_BOTS_SKIP_SNIPER, "1", "Arms Race: bots skip the Sniper Rifle rank and advance to the next weapon instead (1=on, 0=off).") } catch (e55) {}
    try { Convars.RegisterConvar(MERC_CVAR_GG_BOTS_SKIP_SNIPER, 1, "Arms Race: bots skip the Sniper Rifle rank and advance to the next weapon instead (1=on, 0=off).", 0) } catch (e56) {}

    rt.__mercConvarsReady <- true
}

function __Merc_JumpSoundsEnabled()
{
    __Merc_RegisterConVars()

    local rt = getroottable()
    local v = 1

    if ("Convars" in rt)
    {
        try { v = Convars.GetInt(MERC_CVAR_JUMPSOUNDS) } catch (e0) {}
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetFloat(MERC_CVAR_JUMPSOUNDS).tointeger() } catch (e1) {}
        }
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetStr(MERC_CVAR_JUMPSOUNDS).tointeger() } catch (e2) {}
        }
    }
    else if ("__mercJumpSoundsDefault" in rt)
    {
        v = rt.__mercJumpSoundsDefault
    }

    return (v != 0)
}

function __Merc_SpawnProtectSeconds()
{
    __Merc_RegisterConVars()

    local rt = getroottable()
    local secs = 3.0

    if ("Convars" in rt)
    {
        try { secs = Convars.GetFloat(MERC_CVAR_SPAWNPROTECT).tofloat() } catch (e0) {}
        if (secs == 0.0)
        {
            local iv = 0
            try { iv = Convars.GetInt(MERC_CVAR_SPAWNPROTECT) } catch (e1) { iv = 0 }
            secs = iv.tofloat()
        }
        if (secs == 0.0)
        {
            local sv = "0"
            try { sv = Convars.GetStr(MERC_CVAR_SPAWNPROTECT) } catch (e2) { sv = "0" }
            try { secs = sv.tofloat() } catch (e3) { secs = 0.0 }
        }
    }
    else if ("__mercSpawnProtectDefault" in rt)
    {
        secs = rt.__mercSpawnProtectDefault
    }

    if (secs < 0.0) secs = 0.0
    return secs
}

function __Merc_GetBinaryCVar(cvarName, defaultValue)
{
    __Merc_RegisterConVars()

    local rt = getroottable()
    local v = defaultValue

    if ("Convars" in rt)
    {
        try { v = Convars.GetInt(cvarName) } catch (e0) {}
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetFloat(cvarName).tointeger() } catch (e1) {}
        }
        if (v != 0 && v != 1)
        {
            try { v = Convars.GetStr(cvarName).tointeger() } catch (e2) {}
        }
    }

    return (v != 0) ? 1 : 0
}

function __Merc_ShouldGrantNoFallDamage()
{
    local defaultValue = ("__mercFallDamageDefault" in getroottable()) ? ::__mercFallDamageDefault : 0
    return (__Merc_GetBinaryCVar(MERC_CVAR_FALLDAMAGE, defaultValue) == 0)
}

function __Merc_ArmsRaceBotsSkipSniperEnabled()
{
    local defaultValue = ("__mercGGBotsSkipSniperDefault" in getroottable()) ? ::__mercGGBotsSkipSniperDefault : 1
    return (__Merc_GetBinaryCVar(MERC_CVAR_GG_BOTS_SKIP_SNIPER, defaultValue) != 0)
}
getroottable()["__Merc_ArmsRaceBotsSkipSniperEnabled"] <- __Merc_ArmsRaceBotsSkipSniperEnabled;

function __Merc_PreserveSourceLogicEnabled()
{
    return (("__mercPreserveSourceLogicDefault" in getroottable()) ? ::__mercPreserveSourceLogicDefault : 0) != 0
}
getroottable()["__Merc_PreserveSourceLogicEnabled"] <- __Merc_PreserveSourceLogicEnabled;

function __Merc_ShouldSkipPreservedPostInventory()
{
    if (!__Merc_PreserveSourceLogicEnabled())
        return false;
    return !__Merc_RandomizerEnabled();
}

function __Merc_NormalizeBaselineHealth(player, baselineHp = 150, maxStockHp = 200)
{
    if (!__IsValidPlayer(player))
        return;
    if (!__IsOnPlayableTeam(player))
        return;

    local currentHp = 0;
    try { currentHp = player.GetHealth().tointeger(); } catch (e0) { currentHp = 0; }
    if (currentHp <= baselineHp || currentHp > maxStockHp)
        return;

    local didSet = false;
    try
    {
        if ("SetHealth" in player)
        {
            player.SetHealth(baselineHp);
            didSet = true;
        }
    }
    catch (e1) { didSet = false; }

    if (!didSet && ("NetProps" in getroottable()))
    {
        try { NetProps.SetPropInt(player, "m_iHealth", baselineHp); } catch (e2) {}
    }
}
getroottable()["__Merc_NormalizeBaselineHealth"] <- __Merc_NormalizeBaselineHealth;

function __Merc_ScheduleBaselineHealthNormalize(player, delay, suffix)
{
    if (!__IsValidPlayer(player))
        return;

    local thinkName = format("MercHealthNormalize_%d_%s", player.entindex(), suffix);
    player.SetContextThink(thinkName, function()
    {
        try { __Merc_NormalizeBaselineHealth(player); } catch (e0) {}
        return null;
    }, delay);
}

function __Merc_SetServerCVarBool(targetName, enabledInt)
{
    local enabledStr = enabledInt.tostring()

    if ("Convars" in getroottable())
    {
        try { Convars.SetValue(targetName, enabledInt) } catch (e0) {}
        try { Convars.SetValue(targetName, enabledStr) } catch (e1) {}
        try { Convars.SetStr(targetName, enabledStr) } catch (e2) {}
    }

    // Fallback path for branches that expose server-console dispatch.
    try
    {
        if ("SendToConsoleServer" in getroottable())
            SendToConsoleServer(targetName + " " + enabledStr)
    }
    catch (e3) {}
}

function __Merc_GetNumericCVar(cvarName, defaultValue)
{
    __Merc_RegisterConVars()

    local rt = getroottable()
    local v = defaultValue

    if ("Convars" in rt)
    {
        try { v = Convars.GetFloat(cvarName).tofloat() } catch (e0) {}
        if (v == 0.0)
        {
            local iv = 0
            try { iv = Convars.GetInt(cvarName) } catch (e1) { iv = 0 }
            if (iv != 0 || defaultValue == 0.0)
                v = iv.tofloat()
        }
        if (v == 0.0 && defaultValue != 0.0)
        {
            local sv = ""
            try { sv = Convars.GetStr(cvarName) } catch (e2) { sv = "" }
            if (sv != "")
            {
                try { v = sv.tofloat() } catch (e3) {}
            }
        }
    }

    return v
}

function __Merc_SetServerCVarNumeric(targetName, valueNum)
{
    local valueStr = valueNum.tostring()

    if ("Convars" in getroottable())
    {
        try { Convars.SetValue(targetName, valueNum) } catch (e0) {}
        try { Convars.SetValue(targetName, valueStr) } catch (e1) {}
        try { Convars.SetStr(targetName, valueStr) } catch (e2) {}
    }

    try
    {
        if ("SendToConsoleServer" in getroottable())
            SendToConsoleServer(targetName + " " + valueStr)
    }
    catch (e3) {}
}

function __Merc_ApplyServerCVarPolicies()
{
    local gamemode = __Merc_GameMode()
    local disableRespawnTimes = __Merc_GetBinaryCVar(MERC_CVAR_DISABLE_RESPAWN_TIMES, ("__mercDisableRespawnTimesDefault" in getroottable()) ? ::__mercDisableRespawnTimesDefault : 1)
    local playerGib = __Merc_GetBinaryCVar(MERC_CVAR_PLAYERGIB, ("__mercPlayerGibDefault" in getroottable()) ? ::__mercPlayerGibDefault : 0)
    local autojump = __Merc_GetBinaryCVar(MERC_CVAR_AUTOJUMP, ("__mercAutojumpDefault" in getroottable()) ? ::__mercAutojumpDefault : 1)
    local duckjump = __Merc_GetBinaryCVar(MERC_CVAR_DUCKJUMP, ("__mercDuckjumpDefault" in getroottable()) ? ::__mercDuckjumpDefault : 1)
    local airaccelerate = __Merc_GetNumericCVar(MERC_CVAR_AIRACCELERATE, ("__mercAiraccelerateDefault" in getroottable()) ? ::__mercAiraccelerateDefault : 50.0)
    local bhopMaxSpeedFactor = __Merc_GetNumericCVar(MERC_CVAR_BHOP_MAX_SPEED_FACTOR, ("__mercBhopMaxSpeedFactorDefault" in getroottable()) ? ::__mercBhopMaxSpeedFactorDefault : -1.0)
    local groundspeedCap = __Merc_GetNumericCVar(MERC_CVAR_GROUNDSPEED_CAP, ("__mercGroundspeedCapDefault" in getroottable()) ? ::__mercGroundspeedCapDefault : -1.0)
    local fragLimit = __Merc_GetNumericCVar(MERC_CVAR_FRAGLIMIT, ("__mercFraglimitDefault" in getroottable()) ? ::__mercFraglimitDefault : -1.0)
    local dropWeaponsEnable = __Merc_GetBinaryCVar(MERC_CVAR_DROPWEAPONS_ENABLE, ("__mercDropWeaponsEnableDefault" in getroottable()) ? ::__mercDropWeaponsEnableDefault : 1)
    local botBotLoadouts = __Merc_GetBinaryCVar(MERC_CVAR_BOT_BOTLOADOUTS, ("__mercBotBotLoadoutsDefault" in getroottable()) ? ::__mercBotBotLoadoutsDefault : 1)

    // Instagib enforces gibbing/infinite ammo regardless of configured defaults.
    if (gamemode == 2)
    {
        playerGib = 1
        __Merc_SetServerCVarBool(MERC_CVAR_PLAYERGIB, 1)
    }

    if (gamemode == 1 || gamemode == 2 || gamemode == 4)
    {
        dropWeaponsEnable = 0
        __Merc_SetServerCVarBool(MERC_CVAR_DROPWEAPONS_ENABLE, 0)
        __Merc_SetServerCVarBool(MERC_CVAR_WEAPONSPAWNERS_USE, 0)
        botBotLoadouts = 0
        __Merc_SetServerCVarBool(MERC_CVAR_BOT_BOTLOADOUTS, 0)
    }

    if (__Merc_IsInfectionMap())
    {
        botBotLoadouts = 0
        __Merc_SetServerCVarBool(MERC_CVAR_BOT_BOTLOADOUTS, 0)
    }

    __Merc_SetServerCVarBool("tf2c_bot_random_loadouts", 0)
    __Merc_SetServerCVarBool("mp_disable_respawn_times", disableRespawnTimes)
    if (gamemode == 2)
    {
        __Merc_SetServerCVarNumeric("tf_playergib", 2)
        __Merc_SetServerCVarBool("tf2c_infinite_ammo", 1)
    }
    else
    {
        __Merc_SetServerCVarBool("tf_playergib", playerGib)
        __Merc_SetServerCVarBool("tf2c_infinite_ammo", 0)
    }
    __Merc_SetServerCVarBool("tf2c_autojump", autojump)
    __Merc_SetServerCVarBool("tf2c_duckjump", duckjump)
    __Merc_SetServerCVarBool("tf_allow_player_use", 1)
    __Merc_SetServerCVarNumeric("tf2c_domination_override_pointlimit", fragLimit)
    __Merc_SetServerCVarNumeric("sv_airaccelerate", airaccelerate)
    __Merc_SetServerCVarNumeric("tf2c_bunnyjump_max_speed_factor", bhopMaxSpeedFactor)
    __Merc_SetServerCVarNumeric("tf2c_groundspeed_cap", groundspeedCap)
    if (gamemode == 0)
        __Merc_SetServerCVarBool(MERC_CVAR_DROPWEAPONS_ENABLE, dropWeaponsEnable)
    if (gamemode == 0 && !__Merc_IsInfectionMap())
        __Merc_SetServerCVarBool(MERC_CVAR_BOT_BOTLOADOUTS, botBotLoadouts)
}

function __Merc_GameMode()
{
    local gm = __Merc_GetNumericCVar(MERC_CVAR_GAMEMODE, ("__mercGamemodeDefault" in getroottable()) ? ::__mercGamemodeDefault : 1)
    local gmi = 1
    try { gmi = gm.tointeger() } catch (e0) { gmi = 1 }
    if (gmi < 0) gmi = 0
    if (gmi > 4) gmi = 4
    return gmi
}

function __Merc_RandomizerEnabled()
{
    return (__Merc_GameMode() == 1)
}

function __Merc_InstagibEnabled()
{
    return (__Merc_GameMode() == 2)
}

function __Merc_ArmsRaceEnabled()
{
    return (__Merc_GameMode() == 4)
}

function __Merc_AmmoPacksEnabled()
{
    return (__Merc_DeathDropsEnabled() && (__Merc_GetBinaryCVar(MERC_CVAR_AMMOPACKS, ("__mercAmmoPacksDefault" in getroottable()) ? ::__mercAmmoPacksDefault : 1) != 0))
}
getroottable()["__Merc_AmmoPacksEnabled"] <- __Merc_AmmoPacksEnabled;

function __Merc_DropWeaponsUseEnabled()
{
    if (__Merc_ArmsRaceEnabled())
        return false
    return (__Merc_GetBinaryCVar(MERC_CVAR_DROPWEAPONS_USE, ("__mercDropWeaponsUseDefault" in getroottable()) ? ::__mercDropWeaponsUseDefault : 0) != 0)
}
getroottable()["__Merc_DropWeaponsUseEnabled"] <- __Merc_DropWeaponsUseEnabled;

function __Merc_DeathDropsEnabled()
{
    if (__Merc_ArmsRaceEnabled())
        return false
    return (__Merc_GetBinaryCVar(MERC_CVAR_DROPWEAPONS_ENABLE, ("__mercDropWeaponsEnableDefault" in getroottable()) ? ::__mercDropWeaponsEnableDefault : 1) != 0)
}
getroottable()["__Merc_DeathDropsEnabled"] <- __Merc_DeathDropsEnabled;

function __Merc_DroppedWeaponDespawnTime()
{
    local secs = __Merc_GetNumericCVar(MERC_CVAR_DROPPED_WEAPON_DESPAWNTIME, 15.0)
    if (secs < 0.1)
        secs = 0.1
    return secs
}
getroottable()["__Merc_DroppedWeaponDespawnTime"] <- __Merc_DroppedWeaponDespawnTime;

function __Merc_DroppedAmmoBoxDespawnTime()
{
    local secs = __Merc_GetNumericCVar(MERC_CVAR_DROPPED_AMMOBOX_DESPAWNTIME, 15.0)
    if (secs < 0.1)
        secs = 0.1
    return secs
}
getroottable()["__Merc_DroppedAmmoBoxDespawnTime"] <- __Merc_DroppedAmmoBoxDespawnTime;

function __Merc_WeaponSpawnersUseEnabled()
{
    if (__Merc_ArmsRaceEnabled())
        return false
    return (__Merc_GetBinaryCVar(MERC_CVAR_WEAPONSPAWNERS_USE, ("__mercWeaponSpawnersUseDefault" in getroottable()) ? ::__mercWeaponSpawnersUseDefault : 0) != 0)
}
getroottable()["__Merc_WeaponSpawnersUseEnabled"] <- __Merc_WeaponSpawnersUseEnabled;

function __Merc_WeaponSpawnersReplacePistolEnabled()
{
    return (__Merc_GetBinaryCVar(MERC_CVAR_WEAPONSPAWNERS_REPLACE_PISTOL, ("__mercWeaponSpawnersReplacePistolDefault" in getroottable()) ? ::__mercWeaponSpawnersReplacePistolDefault : 0) != 0)
}
getroottable()["__Merc_WeaponSpawnersReplacePistolEnabled"] <- __Merc_WeaponSpawnersReplacePistolEnabled;

function __Merc_WeaponStayEnabled()
{
    return (__Merc_GetBinaryCVar(MERC_CVAR_WEAPONSTAY, ("__mercWeaponStayDefault" in getroottable()) ? ::__mercWeaponStayDefault : 0) != 0)
}
getroottable()["__Merc_WeaponStayEnabled"] <- __Merc_WeaponStayEnabled;

function __Merc_GetCurrentMapName()
{
    local rt = getroottable()
    if ("Convars" in rt)
    {
        local names = [ "mapname", "host_map" ]
        foreach (name in names)
        {
            local value = ""
            try { value = Convars.GetStr(name) } catch (e0) { value = "" }
            if (value != null && value != "")
                return value.tolower()
        }
    }
    return ""
}

function __Merc_IsInfectionMap()
{
    local mapName = __Merc_GetCurrentMapName()
    return (mapName != "" && mapName.find("inf_") == 0)
}

function __Merc_BotBotLoadoutsEnabled()
{
    if (__Merc_GameMode() != 0)
        return false
    if (__Merc_IsInfectionMap())
        return false
    return (__Merc_GetBinaryCVar(MERC_CVAR_BOT_BOTLOADOUTS, ("__mercBotBotLoadoutsDefault" in getroottable()) ? ::__mercBotBotLoadoutsDefault : 1) != 0)
}

function __Merc_IsBotPlayer(player, params = null)
{
    if (!__IsValidPlayer(player))
        return false

    if (params != null)
    {
        try
        {
            if ("bot" in params && params.bot.tointeger() != 0)
                return true
        }
        catch (e0) {}
    }

    try
    {
        if ("IsFakeClient" in player)
            return player.IsFakeClient()
    }
    catch (e1) {}

    if ("NetProps" in getroottable())
    {
        try
        {
            if (NetProps.GetPropBool(player, "m_bIsABot"))
                return true
        }
        catch (e2) {}
    }

    return false
}

::g_MercBotLoadoutPool <- [
    { itemDef = 10, className = "tf_weapon_shotgun_soldier" },
    { itemDef = 19, className = "tf_weapon_grenadelauncher" },
    { itemDef = 35, className = "tf_weapon_flaregun" },
    { itemDef = 16, className = "tf_weapon_smg" },
    { itemDef = 2013, className = "tf2c_weapon_doubleshotgun" }
]

getroottable()["MercGiveBotDMWeaponLoadoutByEntIndex"] <- function(entIdx)
{
    if (!__Merc_BotBotLoadoutsEnabled())
        return
    if (!("EntIndexToHScript" in getroottable()))
        return

    local player = null
    try { player = EntIndexToHScript(entIdx) } catch (e0) { player = null }
    if (!__IsValidPlayer(player))
        return
    if (!__IsOnPlayableTeam(player))
        return
    if (!__Merc_IsBotPlayer(player))
        return

    local nowT = __Now()
    if (::g_MercScriptStartTime != null && nowT > 0.0 && (nowT - ::g_MercScriptStartTime) < 40.0)
        return

    local choice = null
    try
    {
        choice = ::g_MercBotLoadoutPool[RandomInt(0, ::g_MercBotLoadoutPool.len() - 1)]
    }
    catch (e1)
    {
        if (::g_MercBotLoadoutPool.len() > 0)
            choice = ::g_MercBotLoadoutPool[0]
    }
    if (choice == null)
        return

    if (!("GivePlayerWeapon" in getroottable()))
        return

    local weapon = null
    try { weapon = GivePlayerWeapon(player, choice.className, choice.itemDef) } catch (e2) { weapon = null }
    if (weapon == null)
        return

    try
    {
        if ("ApplyWeaponAmmoDefaults" in getroottable())
            ApplyWeaponAmmoDefaults(player, weapon, choice.className)
    }
    catch (e3) {}
}

function __Merc_ApplySpawnProtection(player)
{
    if (!__IsValidPlayer(player))
        return
    if (!__IsOnPlayableTeam(player))
        return

    local protectSeconds = __Merc_SpawnProtectSeconds()
    if (protectSeconds <= 0.0)
        return

    // Spawn/class force can produce bursty spawn callbacks; don't stack repeatedly.
    local entIdx = -1
    try { entIdx = player.entindex() } catch (eE) { entIdx = -1 }
    local nowT = __Now()
    if (entIdx >= 0)
    {
        local lastT = 0.0
        if (entIdx in ::g_MercLastSpawnProtectTime)
            lastT = ::g_MercLastSpawnProtectTime[entIdx]
        if (nowT > 0.0 && (nowT - lastT) < 0.60)
            return
        ::g_MercLastSpawnProtectTime[entIdx] <- nowT
    }

    local didApply = false
    try
    {
        if ("AddCond" in player)
        {
            player.AddCond(TF_COND_UBERCHARGED, protectSeconds)
            didApply = true
        }
    }
    catch (e0) { didApply = false }

    if (!didApply)
    {
        try
        {
            if ("AddCondEx" in player)
            {
                player.AddCondEx(TF_COND_UBERCHARGED, protectSeconds, null)
                didApply = true
            }
        }
        catch (e1) { didApply = false }
    }

    if (!didApply)
        return

    // Explicit revoke after configured time as a safety net across branch differences.
    local thinkName = format("MercSpawnProtectEnd_%d", player.entindex())
    player.SetContextThink(thinkName, function()
    {
        if (__IsValidPlayer(player))
        {
            try { if ("RemoveCond" in player) player.RemoveCond(TF_COND_UBERCHARGED) } catch (e2) {}
        }
        return null
    }, protectSeconds + 0.01)
}

getroottable()["PlayMercJumpSound"] <- function(player, _unused = null)
{
    // Some callback paths can pass an extra implicit argument; normalize.
    if (player == null && _unused != null)
        player = _unused

    if (player == null || !player.IsValid() || !player.IsPlayer())
        return

    // Root-safe jump cvar check; do not depend on file-local helper resolution.
    local jumpEnabled = 1
    if ("Convars" in getroottable())
    {
        try { jumpEnabled = Convars.GetInt("tf2c_dm_jumpsounds") } catch (e0) { jumpEnabled = 1 }
        if (jumpEnabled != 0 && jumpEnabled != 1)
        {
            try { jumpEnabled = Convars.GetFloat("tf2c_dm_jumpsounds").tointeger() } catch (e1) { jumpEnabled = 1 }
        }
        if (jumpEnabled != 0 && jumpEnabled != 1)
        {
            try { jumpEnabled = Convars.GetStr("tf2c_dm_jumpsounds").tointeger() } catch (e2) { jumpEnabled = 1 }
        }
    }
    if (jumpEnabled == 0)
        return

    local n = 1
    try { n = RandomInt(1, MERC_JUMP_SOUND_COUNT) } catch (e) { n = 1 }

    local snd = MERC_JUMP_SOUND_PREFIX + n.tostring() + MERC_JUMP_SOUND_SUFFIX

    try
    {
        if ("__Merc_EmitSpatialJumpSound" in getroottable())
        {
            getroottable()["__Merc_EmitSpatialJumpSound"](player, snd)
            return
        }
    }
    catch (e3) {}

    try { EmitSoundOn(snd, player) } catch (e4) {}
}

getroottable()["PlayMercRespawnVoice"] <- function(player)
{
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return

    local n = 1
    try { n = RandomInt(1, MERC_RESPAWN_VOICE_COUNT) } catch (e0) { n = 1 }

    local idx = n.tostring()
    if (n < 10)
        idx = "0" + idx

    local snd = MERC_RESPAWN_VOICE_PREFIX + idx + MERC_RESPAWN_VOICE_SUFFIX

    try
    {
        local pos = player.GetOrigin()
        local params =
        {
            sound_name = snd,
            entity = player,
            speakerentity = player.entindex(),
            origin = pos,
            channel = CHAN_VOICE,
            volume = MERC_RESPAWN_VOICE_VOLUME,
            pitch = 100,
            soundlevel = MERC_LOCAL_SNDLVL
        }
        EmitSoundEx(params)
        return
    }
    catch (e1) {}

    try { EmitSoundOn(snd, player) } catch (e2) {}
}

getroottable()["MercJumpThink"] <- function()
{
    // 'self' is player entity here when bound into scope
    local player = self

    // Read buttons + flags via netprops (most reliable across branches)
    local buttons = 0
    local flags = 0
    try { buttons = NetProps.GetPropInt(player, "m_nButtons") } catch (e) { buttons = 0 }
    try { flags = NetProps.GetPropInt(player, "m_fFlags") } catch (e) { flags = 0 }

    // Constants (avoid relying on Constants.* being present)
    const IN_JUMP = 2
    const FL_ONGROUND = 1

    local onGroundNow = ((flags & FL_ONGROUND) != 0)
    local jumpNow = ((buttons & IN_JUMP) != 0)

    // Use player scope for edge detection
    player.ValidateScriptScope()
    local sc = player.GetScriptScope()
    if (!("lastButtons" in sc)) sc.lastButtons <- 0
    if (!("lastOnGround" in sc)) sc.lastOnGround <- true

    local jumpPrev = ((sc.lastButtons & IN_JUMP) != 0)

    // Play when we actually leave the ground while jump is held.
    // This supports holding space (autojump/bhop) because it triggers on the ground->air transition.
    if (sc.lastOnGround && !onGroundNow && jumpNow)
    {
        PlayMercJumpSound(player)
    }

    // Aggressive 320-speed maintenance without competing for another entity think slot.
    try
    {
        local team = 0
        try { team = player.GetTeam() } catch (eT) { team = 0 }
        if (team >= 2)
            __ApplyMercSpeedNow(player)
    }
    catch (eSpd) {}
sc.lastButtons = buttons
    sc.lastOnGround = onGroundNow

    return -1
}

getroottable()["EnsureJumpThink"] <- function(player)
{
    if (player == null || !player.IsValid())
        return

    player.ValidateScriptScope()
    local sc = player.GetScriptScope()
    if ("hasJumpThink" in sc && sc.hasJumpThink)
        return

    sc.MercJumpThink <- MercJumpThink
    AddThinkToEnt(player, "MercJumpThink")
    sc.hasJumpThink <- true
}



// ---- helpers ----
function __IsValidPlayer(p)
{
	return (p != null && p.IsValid() && p.IsPlayer());
}
getroottable()["__IsValidPlayer"] <- __IsValidPlayer;

function __Merc_EmitSpatialJumpSound(player, snd, soundLevel = MERC_LOCAL_SNDLVL)
{
    if (player == null || !player.IsValid() || !player.IsPlayer() || snd == null || snd == "")
        return

    try
    {
        local pos = player.GetOrigin()
        local params =
        {
            sound_name = snd,
            entity = player,
            speakerentity = player.entindex(),
            origin = pos,
            channel = CHAN_AUTO,
            volume = 1.0,
            pitch = 100,
            soundlevel = soundLevel
        }
        EmitSoundEx(params)
        return
    }
    catch (e0) {}

    try { EmitSoundOn(snd, player) } catch (e1) {}
}
getroottable()["__Merc_EmitSpatialJumpSound"] <- __Merc_EmitSpatialJumpSound;

function __Merc_PlayClientTeleporterTouch(player, soundName = "Teleport.Touch")
{
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return

    try { EmitSoundOnClient(soundName, player, player); return; } catch (e0) {}
    try { EmitSoundOnClient(soundName, player); return; } catch (e1) {}

    try
    {
        local pos = player.GetOrigin()
        local params =
        {
            sound_name = soundName,
            entity = player,
            speakerentity = player.entindex(),
            origin = pos,
            channel = CHAN_AUTO,
            volume = 1.0,
            pitch = 100,
            soundlevel = SNDLVL_NONE
        }
        EmitSoundEx(params)
        return
    }
    catch (e2) {}

    try { EmitSoundOn(soundName, player) } catch (e3) {}
}
getroottable()["__Merc_PlayClientTeleporterTouch"] <- __Merc_PlayClientTeleporterTouch;

function __Merc_RefreshFallDamageState(player)
{
    if (!__IsValidPlayer(player))
        return

    try
    {
        if ("RemoveCustomAttribute" in player)
            player.RemoveCustomAttribute("cancel falling damage")
    }
    catch (e0) {}

    try
    {
        if (__Merc_ShouldGrantNoFallDamage() && "AddCustomAttribute" in player)
            player.AddCustomAttribute("cancel falling damage", 1, -1)
    }
    catch (e1) {}
}

function __Merc_ScheduleFallDamageRefresh(player, delay, suffix)
{
    if (!__IsValidPlayer(player))
        return

    local thinkName = format("MercFallDamageRefresh_%d_%s", player.entindex(), suffix)
    try
    {
        player.SetContextThink(thinkName, function()
        {
            try { __Merc_RefreshFallDamageState(player) } catch (e0) {}
            return null
        }, delay)
    }
    catch (e1) {}
}

getroottable()["__Merc_RefreshFallDamageState"] <- __Merc_RefreshFallDamageState;
getroottable()["__Merc_ScheduleFallDamageRefresh"] <- __Merc_ScheduleFallDamageRefresh;

function __Now()
{
	try { return Time(); } catch (e) { return 0.0; }
}

function __IsOnPlayableTeam(player)
{
	// Keep this helper self-contained because callback scopes can differ on srcds.
	if (player == null)
		return false;
	try
	{
		if (!player.IsValid() || !player.IsPlayer())
			return false;
	}
	catch (e0)
		return false;

	local team = 0;
	try { team = player.GetTeam(); } catch (e1) { team = 0; }
	return (team >= 2);
}

// Ensure callbacks can resolve helpers even when invoked from root callback scope.
getroottable()["__IsOnPlayableTeam"] <- __IsOnPlayableTeam;

function __ForceSoldier(player)
{
	if (!__IsValidPlayer(player))
		return false;
	if (!__IsOnPlayableTeam(player))
		return false;

	// Desired class (helps stickiness)
	try { NetProps.SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SOLDIER); } catch (e) {}

	local currentClass = null;
	try { currentClass = NetProps.GetPropInt(player, "m_PlayerClass.m_iClass"); } catch (e) { currentClass = null; }

	if (currentClass == null || currentClass == TF_CLASS_SOLDIER)
		return false;

	// Guard regen spam
	local entIdx = player.entindex();
	local now = __Now();
	if (entIdx in ::g_forceClassLastTime)
	{
		if ((now - ::g_forceClassLastTime[entIdx]) < 0.35)
			return true;
	}
	::g_forceClassLastTime[entIdx] <- now;

	// Change class + regen
	try { if ("SetPlayerClass" in player) player.SetPlayerClass(TF_CLASS_SOLDIER); } catch (e) {}
	try
	{
		if ("ForceRegenerateAndRespawn" in player) player.ForceRegenerateAndRespawn();
		else if ("ForceRespawn" in player) player.ForceRespawn();
	}
	catch (e) {}

	return true;
}

function __ApplyMercModelNow(player)
{
	if (!__IsValidPlayer(player))
		return;
	if (!__IsOnPlayableTeam(player))
		return;

	local applied = false;

	// Prefer class-anim custom model if present
	try
	{
		if ("SetCustomModelWithClassAnimations" in player)
		{
			player.SetCustomModelWithClassAnimations(MERC_MODEL);
			applied = true;
		}
	}
	catch (e) {}

	// TF2C SetCustomModel appears to be 1-arg only.
	if (!applied)
	{
		try
		{
			if ("SetCustomModel" in player)
			{
				player.SetCustomModel(MERC_MODEL);
				applied = true;
			}
		}
		catch (e) {}
	}

	// Fallback
	try { player.SetModel(MERC_MODEL); } catch (e) {}
}

function __ScheduleReapplyModel(player, delay, suffix)
{
	if (!__IsValidPlayer(player))
		return;

	local thinkName = format("MercModelReapply_%d_%s", player.entindex(), suffix);

	player.SetContextThink(thinkName, function()
	{
		if (!__IsOnPlayableTeam(player))
			return null;

		try { NetProps.SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SOLDIER); } catch (e) {}
		__ApplyMercModelNow(player);
		return null;
	}, delay);
}

function __Merc_ClearSpeedAttributes(player)
{
    try
    {
        if ("RemoveCustomAttribute" in player)
            player.RemoveCustomAttribute("move speed bonus")
    }
    catch (e0) {}

    try
    {
        if ("RemoveCustomAttribute" in player)
            player.RemoveCustomAttribute("major move speed bonus")
    }
    catch (e1) {}
}

function __ApplyMercSpeedNow(player)
{
    if (!__IsValidPlayer(player))
        return
    if (!__IsOnPlayableTeam(player))
        return

    __Merc_ClearSpeedAttributes(player)

    if (!MERC_ENABLE_SPEED_ADJUSTMENTS)
        return

    try
    {
        if ("AddCustomAttribute" in player)
            player.AddCustomAttribute("move speed bonus", MERC_MEDIC_SPEED_MULT, -1)
    }
    catch (e0) {}
}
getroottable()["__ApplyMercSpeedNow"] <- __ApplyMercSpeedNow;

function __ScheduleReapplySpeed(player, delay, suffix)
{
    if (!MERC_ENABLE_SPEED_ADJUSTMENTS)
        return
    if (!__IsValidPlayer(player))
        return

    local thinkName = format("MercSpeedReapply_%d_%s", player.entindex(), suffix)
    player.SetContextThink(thinkName, function()
    {
        __ApplyMercSpeedNow(player)
        return null
    }, delay)
}

getroottable()["MercSpeedThink"] <- function(_unused = null)
{
    local player = self
    if (player == null || !player.IsValid() || !player.IsPlayer())
        return null

    if (__IsOnPlayableTeam(player))
    {
        if ("__ApplyMercSpeedNow" in getroottable())
            getroottable()["__ApplyMercSpeedNow"](player)
        else
            __ApplyMercSpeedNow(player)
    }
    else
    {
        __Merc_ClearSpeedAttributes(player)
    }

    return 0.25
}

getroottable()["EnsureSpeedThink"] <- function(player)
{
    if (!MERC_ENABLE_SPEED_ADJUSTMENTS)
        return
    if (player == null || !player.IsValid())
        return

    local thinkName = format("MercSpeedThink_%d", player.entindex())
    player.ValidateScriptScope()
    local sc = player.GetScriptScope()
    if ("hasSpeedThink" in sc && sc.hasSpeedThink == thinkName)
        return

    sc.hasSpeedThink <- thinkName
    player.SetContextThink(thinkName, function()
    {
        if (player == null)
            return null
        try
        {
            if (!player.IsValid() || !player.IsPlayer())
                return null
        }
        catch (e0) { return null }

        local team = 0
        try { team = player.GetTeam() } catch (e1) { team = 0 }
        if (team >= 2)
        {
            if ("__ApplyMercSpeedNow" in getroottable())
                getroottable()["__ApplyMercSpeedNow"](player)
            else
                __ApplyMercSpeedNow(player)
        }
        else
        {
            __Merc_ClearSpeedAttributes(player)
        }

        return 0.25
    }, 0.25)

    // Speed maintenance is integrated into MercJumpThink.
    try { EnsureJumpThink(player) } catch (e) {}
}

function __StripWeaponsAll(player)
{
	local usedHelper = false;

	if ("StripWeapons" in getroottable())
	{
		StripWeapons(player);
		usedHelper = true;
	}
	else if ("StripWeaponSlot" in getroottable())
	{
		StripWeaponSlot(player, 0);
		StripWeaponSlot(player, 1);
		StripWeaponSlot(player, 2);
		usedHelper = true;
	}

	// Force-sweep weapon handles to guarantee primary/other leftovers are removed.
	if ("NetProps" in getroottable())
	{
		for (local i = 0; i < 8; i++)
		{
			local wpn = null;
			try { wpn = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i); } catch (e0) { wpn = null; }
			if (wpn == null)
				continue;

			try { wpn.Destroy(); } catch (e1) { try { wpn.Kill(); } catch (e2) {} }
			try { NetProps.SetPropEntityArray(player, "m_hMyWeapons", null, i); } catch (e3) {}
		}
		return;
	}

	// If no helper and no NetProps, do nothing further.
	if (!usedHelper)
	{
		return;
	}
}

function __Merc_DestroyEntitySafe(ent)
{
    if (ent == null)
        return
    try { ent.Destroy() } catch (e0) { try { ent.Kill() } catch (e1) {} }
}

function __RemoveWearablesAll(player)
{
    if (player == null)
        return

    local entIndex = -1
    try { entIndex = player.entindex() } catch (e0) { entIndex = -1 }
    if (entIndex <= 0)
        return

    local wearableClasses = [
        "tf_wearable",
        "tf_wearable_vm",
        "tf_weapon_wearable",
        "tf_wearable_demoshield"
    ]

    foreach (cls in wearableClasses)
    {
        local ent = null
        while ((ent = Entities.FindByClassname(ent, cls)) != null)
        {
            local owner = null
            try { owner = NetProps.GetPropEntity(ent, "m_hOwnerEntity") } catch (e1) { owner = null }
            if (owner != player)
                continue
            __Merc_DestroyEntitySafe(ent)
        }
    }
}

getroottable()["__RemoveWearablesAll"] <- __RemoveWearablesAll;

function __Merc_ApplyOwnedMeleeAttributes(melee)
{
    if (melee == null)
        return

    try
    {
        if ("AddAttribute" in melee)
        {
            if (__Merc_ShouldGrantNoFallDamage())
                melee.AddAttribute("cancel falling damage", 1, -1)
        }
    }
    catch (e0) {}
}

getroottable()["__Merc_ApplyOwnedMeleeAttributes"] <- __Merc_ApplyOwnedMeleeAttributes;

function __GiveFallbackLoadout(player)
{
	// Ensure GivePlayerWeapon exists even when randomizer is disabled.
	if (!("GivePlayerWeapon" in getroottable()))
	{
		try { __LoadDMRando(); } catch (eLoad) {}
		if (!("GivePlayerWeapon" in getroottable()))
		{
			try { __IncludeScriptSafe("tf2c_weaponspawners.nut", getroottable()); } catch (eLoad2) {}
		}
	}

	local gaveAny = false;

	// Normal mode fallback: no primary, give pistol + shovel.
	if ("GivePlayerWeapon" in getroottable())
	{
		local pistol = null;
		local shovel = null;

		// Clear any stale melee entity before regranting the baseline shovel.
		// This keeps the shovel's -50 max-health stat from stacking if a picked-up
		// melee weapon (or an old shovel entity) survived the previous life.
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

		try { shovel = GivePlayerWeapon(player, "tf_weapon_shovel", 1001); } catch (e0) { shovel = null; }
		try { pistol = GivePlayerWeapon(player, "tf_weapon_pistol_scout", 1000); } catch (e1) { pistol = null; }

        if (shovel != null)
        {
            try { __Merc_ApplyOwnedMeleeAttributes(shovel) } catch (e2) {}
        }

		if (pistol != null || shovel != null)
			gaveAny = true;
	}

	return gaveAny;
}

function __LoadDMRando()
{
	if (!::g_includedDMRando)
		::g_includedDMRando <- __IncludeScriptSafe("tf2c_dmrando.nut", getroottable());
	return ::g_includedDMRando;
}

function __LoadInstagib()
{
	if (!::g_includedInstagib)
		::g_includedInstagib <- __IncludeScriptSafe("tf2c_instagib.nut", getroottable());
	return ::g_includedInstagib;
}

function __LoadArmsRace()
{
	if (!::g_includedArmsRace)
		::g_includedArmsRace <- __IncludeScriptSafe("armsrace.nut", getroottable());
	return ::g_includedArmsRace;
}

function __DebugPrintLoadout(player, reason)
{
	if (!::debugLoadoutPrint)
		return;
	if (!__IsValidPlayer(player))
		return;

	local pieces = [];
	for (local slot = 0; slot <= 5; slot++)
	{
		local w = null;
		try { if ("GetPlayerWeaponSlot" in player) w = player.GetPlayerWeaponSlot(slot); } catch (e) { w = null; }
		if (w == null) { try { if ("GetWeaponBySlot" in player) w = player.GetWeaponBySlot(slot); } catch (e2) { w = null; } }

		if (w != null)
		{
			local cls = "unknown";
			try { cls = w.GetClassname(); } catch (e3) {}

			local def = -1;
			try { def = NetProps.GetPropInt(w, "m_iItemDefinitionIndex"); } catch (e4) { def = -1; }

			pieces.append(format("S%d:%s(%d)", slot, cls, def));
		}
	}

	printl(format("[TF2C] Loadout %s for #%d: %s",
		reason, player.entindex(), pieces.len() ? pieces.join(" ") : "(no weapons)"));
}

function __Merc_SpeedSweepAllPlayers()
{
    local p = null
    while ((p = Entities.FindByClassname(p, "player")) != null)
    {
        if (!__IsValidPlayer(p))
            continue

        // Always attach maintenance thinks, even before team selection.
        // This avoids missing setup when bots spawn first and event ordering differs.
        try { EnsureJumpThink(p) } catch (e1) {}
        if (MERC_ENABLE_SPEED_ADJUSTMENTS)
            try { EnsureSpeedThink(p) } catch (e2) {}

        local team = 0
        try { team = p.GetTeam() } catch (e0) { team = 0 }
        if (team < 2)
            continue

        try { __ApplyMercSpeedNow(p) } catch (e3) {}
    }
}

getroottable()["MercForceSpeedSweepTick"] <- function(hostEnt, serial)
{
    if (serial != ::g_MercSpeedThinkSerial)
        return;

    local runtimeHost = hostEnt;
    if (runtimeHost == null || !runtimeHost.IsValid())
        runtimeHost = ::g_MercRuntimeHost;

    try { __Merc_SpeedSweepAllPlayers(); } catch (e0) {}

    if (runtimeHost != null && runtimeHost.IsValid())
    {
        local code = format("try{ MercForceSpeedSweepTick(self, %d); }catch(e){}", serial);
        try { EntFireByHandle(runtimeHost, "RunScriptCode", code, 0.25, null, null); } catch (e1) {}
    }
}

function ApplyMercTweaks(player, reason)
{
	if (!__IsValidPlayer(player))
		return;

    // Ensure movement/jump maintenance exists even when class-force path returns early.
    try { EnsureJumpThink(player) } catch (eJ0) { }
    if (MERC_ENABLE_SPEED_ADJUSTMENTS)
        try { EnsureSpeedThink(player) } catch (eS0) { }

	if (!__IsOnPlayableTeam(player))
		return;

    __ApplyMercSpeedNow(player)
    __ScheduleReapplySpeed(player, 0.05, "a")

	// Enforce class first; if regen triggered, bail.
	if (__ForceSoldier(player))
		return;

	// Always enforce model
	__ApplyMercModelNow(player);
	__ScheduleReapplyModel(player, 0.05, "a");
	__ScheduleReapplyModel(player, 0.12, "b");

    // Speed to Medic speed (320 / 240 = 1.333333...)
    __ApplyMercSpeedNow(player)
    __ScheduleReapplySpeed(player, 0.05, "a")

	// Jump VO think already ensured above.

// Weapons (throttle so we don't shuffle multiple times during spawn bursts)
	local doShuffle = true;
	local nowT = 0.0;
	try { nowT = Time(); } catch (eT) { nowT = 0.0; }
	local entIdx = -1;
	try { entIdx = player.entindex(); } catch (eE) { entIdx = -1; }
	if (entIdx >= 0)
	{
		local lastT = 0.0;
		if (entIdx in ::g_MercLastLoadoutTime)
			lastT = ::g_MercLastLoadoutTime[entIdx];

		// Throttle only when randomizer mode is active.
		if (__Merc_RandomizerEnabled() && (reason == "spawn" || reason == "post_inventory" || reason == "teamchange"))
		{
			// If we already shuffled very recently, skip shuffling again.
			if (nowT > 0.0 && (nowT - lastT) < 0.60)
				doShuffle = false;
			else
				::g_MercLastLoadoutTime[entIdx] <- nowT;
		}
	}

	if (doShuffle)
	{
		if (__Merc_RandomizerEnabled())
		{
			__StripWeaponsAll(player);
			// Some weapons spawn wearables/attachments; remove them so transient grants don't stick.
			try { __RemoveWearablesAll(player); } catch (eW) {}

			__LoadDMRando();

			if ("GiveMercPrimarySecondary" in getroottable())
				GiveMercPrimarySecondary(player);
			else if ("tf2c_dmrando" in getroottable())
				tf2c_dmrando(player);
			else if ("GiveMercLoadout" in getroottable())
				GiveMercLoadout(player);
			else
				__GiveFallbackLoadout(player);

            __Merc_NormalizeBaselineHealth(player);
            __Merc_ScheduleBaselineHealthNormalize(player, 0.05, "a");
            __Merc_ScheduleBaselineHealthNormalize(player, 0.15, "b");
            __Merc_RefreshFallDamageState(player);
            __Merc_ScheduleFallDamageRefresh(player, 0.05, "a");
            __Merc_ScheduleFallDamageRefresh(player, 0.15, "b");
		}
		else if (__Merc_InstagibEnabled())
		{
			__StripWeaponsAll(player);
			try { __RemoveWearablesAll(player); } catch (eW2) {}
            __LoadInstagib();
            if ("TF2C_Instagib_GiveLoadout" in getroottable())
                TF2C_Instagib_GiveLoadout(player);
            else
			    __GiveFallbackLoadout(player);
            __Merc_RefreshFallDamageState(player);
            __Merc_ScheduleFallDamageRefresh(player, 0.05, "ig_a");
            __Merc_ScheduleFallDamageRefresh(player, 0.15, "ig_b");
		}
        else if (__Merc_ArmsRaceEnabled())
        {
            __StripWeaponsAll(player);
            try { __RemoveWearablesAll(player); } catch (eW4) {}
            __LoadArmsRace();
            if ("TF2C_ArmsRace_GiveLoadout" in getroottable())
                TF2C_ArmsRace_GiveLoadout(player);
            else
                __GiveFallbackLoadout(player);
            __Merc_RefreshFallDamageState(player);
            __Merc_ScheduleFallDamageRefresh(player, 0.05, "gg_a");
            __Merc_ScheduleFallDamageRefresh(player, 0.15, "gg_b");
        }
		else
		{
			__StripWeaponsAll(player);
			try { __RemoveWearablesAll(player); } catch (eW3) {}
			__GiveFallbackLoadout(player);
            __Merc_NormalizeBaselineHealth(player);
            __Merc_ScheduleBaselineHealthNormalize(player, 0.05, "c");
            __Merc_RefreshFallDamageState(player);
            __Merc_ScheduleFallDamageRefresh(player, 0.05, "c");
            __Merc_ScheduleFallDamageRefresh(player, 0.15, "d");
		}
	}

	__ScheduleReapplyModel(player, 0.20, "c");

	// Debug after brief delay
	player.SetContextThink(format("MercDbg_%d_%s", player.entindex(), reason), function()
	{
		__DebugPrintLoadout(player, reason);
		return null;
	}, 0.02);
}

getroottable()["ApplyMercTweaks"] <- ApplyMercTweaks;
getroottable()["__Merc_ApplySpawnProtection"] <- __Merc_ApplySpawnProtection;

function OnGameEvent_player_spawn(params)
{
	local player = GetPlayerFromUserID(params.userid);
	ApplyMercTweaks(player, "spawn");
    __Merc_ApplySpawnProtection(player);
    if (player != null && player.IsValid() && player.IsPlayer())
    {
        local protectSeconds = __Merc_SpawnProtectSeconds();
        if (protectSeconds > 0.0)
        {
            local lateName = format("MercSpawnProtectLate_%d", player.entindex());
            player.SetContextThink(lateName, function()
            {
                try { __Merc_ApplySpawnProtection(player); } catch (eSPL) {}
                return null;
            }, 0.12);
        }

    }

    // One random respawn voice line per spawn burst.
    if (player != null && player.IsValid() && player.IsPlayer() && __IsOnPlayableTeam(player))
    {
        local nowV = 0.0;
        try { nowV = Time(); } catch (eTV) { nowV = 0.0; }
        local entIdxV = -1;
        try { entIdxV = player.entindex(); } catch (eEV) { entIdxV = -1; }
        local doVoice = true;

        // Don't play respawn voice until script has been running long enough.
        local scriptStart = ::g_MercScriptStartTime;
        if (scriptStart != null && nowV > 0.0 && (nowV - scriptStart) < MERC_RESPAWN_VOICE_MIN_SCRIPT_AGE)
            doVoice = false;

        if (nowV > 0.0 && (nowV - ::g_MercLastGlobalRespawnVoiceTime) < MERC_RESPAWN_VOICE_COOLDOWN)
            doVoice = false;

        if (entIdxV >= 0)
        {
            local lastVoice = 0.0;
            if (entIdxV in ::g_MercLastRespawnVoiceTime)
                lastVoice = ::g_MercLastRespawnVoiceTime[entIdxV];
            if (nowV > 0.0 && (nowV - lastVoice) < MERC_RESPAWN_VOICE_COOLDOWN)
                doVoice = false;
            else if (doVoice)
                ::g_MercLastRespawnVoiceTime[entIdxV] <- nowV;
        }
        if (doVoice)
        {
            if (nowV > 0.0)
                ::g_MercLastGlobalRespawnVoiceTime <- nowV;
            try { PlayMercRespawnVoice(player); } catch (eRV) {}
        }
    }

	// One random respawn particle per spawn burst
	if (player != null && player.IsValid() && ("RespawnParticles_PlayRandomOnPlayer" in getroottable()))
	{
		local nowT = 0.0;
		try { nowT = Time(); } catch (eT) { nowT = 0.0; }
		local entIdx = -1;
		try { entIdx = player.entindex(); } catch (eE) { entIdx = -1; }
		local doFx = true;
		if (entIdx >= 0)
		{
			local lastFx = 0.0;
			if (entIdx in ::g_MercLastRespawnFxTime)
				lastFx = ::g_MercLastRespawnFxTime[entIdx];
			if (nowT > 0.0 && (nowT - lastFx) < 0.60)
				doFx = false;
			else
				::g_MercLastRespawnFxTime[entIdx] <- nowT;
		}
		if (doFx)
		{
			try { RespawnParticles_PlayRandomOnPlayer(player); } catch (eRP) {}
		}
	}

    if (__Merc_BotBotLoadoutsEnabled() && __Merc_IsBotPlayer(player, params))
    {
        local nowT = __Now()
        if (::g_MercScriptStartTime != null && nowT > 0.0 && (nowT - ::g_MercScriptStartTime) >= 40.0)
        {
            local entIdxBot = -1
            try { entIdxBot = player.entindex() } catch (eBotIdx) { entIdxBot = -1 }
            if (entIdxBot >= 0)
            {
                local runtimeHost = ::g_MercRuntimeHost
                try
                {
                    if (runtimeHost != null && runtimeHost.IsValid())
                        EntFireByHandle(runtimeHost, "RunScriptCode", format("try{ MercGiveBotDMWeaponLoadoutByEntIndex(%d); }catch(e){}", entIdxBot), 0.5, null, null)
                    else
                        MercGiveBotDMWeaponLoadoutByEntIndex(entIdxBot)
                }
                catch (eBotGive)
                {
                    try { MercGiveBotDMWeaponLoadoutByEntIndex(entIdxBot); } catch (eBotFallback) {}
                }
            }
        }
    }
}


function OnGameEvent_post_inventory_application(params)
{
    if (__Merc_ShouldSkipPreservedPostInventory())
        return;

	local player = GetPlayerFromUserID(params.userid);
	ApplyMercTweaks(player, "post_inventory");
}

function OnGameEvent_player_team(params)
{
    if (__Merc_PreserveSourceLogicEnabled())
        return;

	local player = GetPlayerFromUserID(params.userid);
	ApplyMercTweaks(player, "teamchange");
}

function OnGameEvent_player_death(params)
{
    local player = null;
    try { player = GetPlayerFromUserID(params.userid); } catch (e0) { player = null; }
    if (player == null)
        return;

    if ("MercTempPowerups_HandlePlayerDeath" in getroottable())
    {
        try { MercTempPowerups_HandlePlayerDeath(player); } catch (eTP) {}
    }

    if ("MercDeathDrops_OnPlayerDeath" in getroottable())
    {
        try { MercDeathDrops_OnPlayerDeath(player); } catch (e1) {}
    }
}

function Activate()
{
    local runtimeHost = self;

    if (::g_MercScriptStartTime == null)
    {
        try { ::g_MercScriptStartTime = Time(); } catch (eST) { ::g_MercScriptStartTime = 0.0; }
    }
    ::g_MercRuntimeHost = self;

    __Merc_RegisterConVars()
    __Merc_ApplyServerCVarPolicies()

    try
    {
        self.SetContextThink("MercServerCvarPolicyThink", function()
        {
            __Merc_ApplyServerCVarPolicies()
            return 1.0
        }, 1.0)
    }
    catch (eCV) {}

    // Robustness for bot-first spawns / late human joins:
    // periodically ensure speed maintenance is attached and speed is applied.
    try
    {
        self.SetContextThink("MercSpeedSweepThink", function()
        {
            __Merc_SpeedSweepAllPlayers()
            return 0.25
        }, 0.25)
    }
    catch (eSV) {}

    ::g_MercSpeedThinkSerial += 1;
    local speedThinkSerial = ::g_MercSpeedThinkSerial;
    try
    {
        EntFireByHandle(self, "RunScriptCode", format("try{ MercForceSpeedSweepTick(self, %d); }catch(e){}", speedThinkSerial), 0.25, null, null)
    }
    catch (eSV2) {}

    // Always run runtime re-hooks on each execute/round restart.
    try { TF2C_MercSoldierOnly_RuntimeInit(self); } catch (eRI) {}

	try { PrecacheModel(MERC_MODEL); } catch (e) {}
    foreach (gibModel in ::MERC_GIB_MODELS)
    {
        try { PrecacheModel(gibModel); } catch (eGib) {}
    }

	// Precache jump sounds
	try { PrecacheSound("vo/mercenary_jump01.mp3") } catch (e) { }
	try { PrecacheSound("vo/mercenary_jump02.mp3") } catch (e) { }
	try { PrecacheSound("vo/mercenary_jump03.mp3") } catch (e) { }
    for (local i = 1; i <= MERC_RESPAWN_VOICE_COUNT; i++)
    {
        local idx = i.tostring();
        if (i < 10) idx = "0" + idx;
        try { PrecacheSound(MERC_RESPAWN_VOICE_PREFIX + idx + MERC_RESPAWN_VOICE_SUFFIX); } catch (eRVp) {}
    }


	// Respawn particles (respawn.pcf) hook
	if (!::g_includedRespawnParticles)
		::g_includedRespawnParticles <- __IncludeScriptSafe("tf2c_respawn_particles.nut", getroottable());
	if ("RespawnParticles_PrecacheAll" in getroottable())
	{
		try { RespawnParticles_PrecacheAll(); } catch (eRP) {}
	}

	// Overheal (pill) idle fix hooker
	if (!::g_includedOverhealIdleFix)
		::g_includedOverhealIdleFix <- __IncludeScriptSafe("tf2c_overheal_idlefix.nut", getroottable());
	if ("OverhealIdleFix_Init" in getroottable())
	{
        try { OverhealIdleFix_Init(runtimeHost); } catch (e2) {}
	}

    if (!("__g_includedDeathDrops" in getroottable()))
        ::__g_includedDeathDrops <- false;
    if (!::__g_includedDeathDrops)
        ::__g_includedDeathDrops <- __IncludeScriptSafe("tf2c_deathdrops.nut", getroottable());
    if ("MercDeathDrops_Init" in getroottable())
    {
        try { MercDeathDrops_Init(runtimeHost); } catch (eDD) {}
    }

    if (!("__g_includedTempPowerups" in getroottable()))
        ::__g_includedTempPowerups <- false;
    if (!::__g_includedTempPowerups)
        ::__g_includedTempPowerups <- __IncludeScriptSafe("tf2c_temp_powerups.nut", getroottable());
    if ("MercTempPowerups_Init" in getroottable())
    {
        try { MercTempPowerups_Init(runtimeHost); } catch (eTPMain) {}
    }

    // Instagib module (active only in gamemode 2)
    if (!::g_includedInstagib)
        ::g_includedInstagib <- __IncludeScriptSafe("tf2c_instagib.nut", getroottable());
    if ("TF2C_Instagib_Init" in getroottable())
    {
        try { TF2C_Instagib_Init(runtimeHost); } catch (eIG) {}
    }

    if (!::g_includedArmsRace)
        ::g_includedArmsRace <- __IncludeScriptSafe("armsrace.nut", getroottable());
    if ("TF2C_ArmsRace_Init" in getroottable())
    {
        try { TF2C_ArmsRace_Init(runtimeHost); } catch (eAR) {}
    }

    if (!::TF2C_MercSoldierOnly_EventsRegistered)
    {
	    __CollectEventCallbacks(this, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
        ::TF2C_MercSoldierOnly_EventsRegistered <- true;
    }
	printl("[TF2C] tf2c_merc_soldieronly base loaded. tf2c_dm_gamemode=" + __Merc_GameMode().tostring());
}

function main()
{
    Activate();
}

Activate();
