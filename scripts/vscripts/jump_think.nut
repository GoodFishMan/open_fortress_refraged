printl("Jump Think Loaded")

MercJumpState <- {}
MercJumpCooldown <- {}

function JumpThink()
{
    local player = null
    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (!player.IsValid())
            continue
        local id = player.entindex()
        if (!(id in MercJumpState))
        {
            MercJumpState[id] <- true
            MercJumpCooldown[id] <- 0.0
        }
        local grounded = false
        if ((player.GetFlags() & 1) != 0)
        {
            grounded = true
        }
		local time = Time()
		local velocity = player.GetVelocity()

		if (MercJumpState[id] == true && grounded == false && velocity.z > 0)
		{
			if (time >= MercJumpCooldown[id])
			{
				if (player.GetPlayerClass() == 3)
				{
					EmitSoundOnClient("Mercenary.Jumpsound", player)
					MercJumpCooldown[id] = time + 0.04
				}
			}
		}
        MercJumpState[id] = grounded
    }
    return 0.02
}

local world = Entities.FindByClassname(null, "worldspawn")
AddThinkToEnt(world, "JumpThink")