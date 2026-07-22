::MercenaryModel <- "models/player/mercenary.mdl";
function OnGameEvent_post_inventory_application(params)
{
	local player = GetPlayerFromUserID(params.userid);
    if (player == null)
        return;
	local applied = false;
	try
	{
		if ("SetCustomModelWithClassAnimations" in player)
		{
			player.SetCustomModelWithClassAnimations(MercenaryModel);
			applied = true;
		}
	}
	catch (e) {}
	if (!applied)
	{
		try
		{
			if ("SetCustomModel" in player)
			{
				player.SetCustomModel(MercenaryModel);
				applied = true;
			}
		}
		catch (e) {}
	}
	try { player.SetModel(MercenaryModel); } catch (e) {} // Fallback
}
__CollectGameEventCallbacks(this);