printl("Jump Think Loaded")

MercJumpState <- {}
MercJumpCooldown <- {}

function JumpThink()
{
    local player = null
    local activePlayers = {}

    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!player.IsValid())
            continue

        local id = player.entindex()
        activePlayers[id] <- true

        if (!(id in MercJumpState))
        {
            MercJumpState[id] <- true
            MercJumpCooldown[id] <- 0.0
        }

        local grounded = ((player.GetFlags() & 1) != 0)
        local velocity = player.GetVelocity()
        local time = Time()

        // Player just left the ground and is moving upward
        if (MercJumpState[id] && !grounded && velocity.z > 0)
        {
            if (time >= MercJumpCooldown[id])
            {
                // Soldier
                if (player.GetPlayerClass() == 3)
                {
                    EmitSoundOnClient("Mercenary.Jumpsound", player)

                    // Prevent duplicate sounds
                    MercJumpCooldown[id] = time + 0.02
                }
            }
        }

        MercJumpState[id] = grounded
    }

    // Remove data for disconnected players
    foreach (id, value in MercJumpState)
    {
        if (!(id in activePlayers))
        {
            delete MercJumpState[id]
            delete MercJumpCooldown[id]
        }
    }

    return 0.04
}

local world = Entities.FindByClassname(null, "worldspawn")
AddThinkToEnt(world, "JumpThink")