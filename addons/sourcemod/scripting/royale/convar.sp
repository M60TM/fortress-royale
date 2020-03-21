static ConVar mp_autoteambalance;
static ConVar mp_teams_unbalance_limit;
static ConVar mp_friendlyfire;
static ConVar tf_avoidteammates;
static ConVar tf_powerup_mode;

void ConVar_Init()
{
	fr_healthmultiplier = CreateConVar("fr_healthmultiplier", "1.5", "Max health multiplier (rounds to lowest 5)", _, true, 0.0);
	fr_fistsdamagemultiplier = CreateConVar("fr_fistsdamagemultiplier", "0.62", "Starting fists damage multiplier", _, true, 0.0);
	
	fr_zone_startdisplay = CreateConVar("fr_zone_startdisplay", "30.0", "", _, true, 0.0);
	fr_zone_display = CreateConVar("fr_zone_display", "30.0", "", _, true, 0.0);
	fr_zone_shrink = CreateConVar("fr_zone_shrink", "30.0", "", _, true, 0.0);
	fr_zone_nextdisplay = CreateConVar("fr_zone_nextdisplay", "0.0", "", _, true, 0.0);
	
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_avoidteammates = FindConVar("tf_avoidteammates");
	tf_powerup_mode = FindConVar("tf_powerup_mode");
}

void ConVar_Toggle(bool enable)
{
	static bool toggled = false;
	
	static int autoteambalance;
	static int teamsUnbalanceLimit;
	static bool friendlyfire;
	static bool avoidteammates;
	static bool powerupmode;
	
	if (enable && !toggled)
	{
		toggled = true;
		
		autoteambalance = mp_autoteambalance.IntValue;
		mp_autoteambalance.IntValue = 0;
		
		teamsUnbalanceLimit = mp_teams_unbalance_limit.IntValue;
		mp_teams_unbalance_limit.IntValue = 0;
		
		friendlyfire = mp_friendlyfire.BoolValue;
		mp_friendlyfire.BoolValue = true;
		
		avoidteammates = tf_avoidteammates.BoolValue;
		tf_avoidteammates.BoolValue = false;
		
		powerupmode = tf_powerup_mode.BoolValue;
		tf_powerup_mode.BoolValue = true;
	}
	else if (!enable && toggled)
	{
		toggled = false;
		
		mp_autoteambalance.IntValue = autoteambalance;
		mp_teams_unbalance_limit.IntValue = teamsUnbalanceLimit;
		mp_friendlyfire.BoolValue = friendlyfire;
		tf_avoidteammates.BoolValue = avoidteammates;
		tf_powerup_mode.BoolValue = powerupmode;
	}
}
