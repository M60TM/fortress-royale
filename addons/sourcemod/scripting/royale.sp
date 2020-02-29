#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define TF_MAXPLAYERS	32

#define CONTENTS_REDTEAM	CONTENTS_TEAM1
#define CONTENTS_BLUETEAM	CONTENTS_TEAM2

#define MODEL_EMPTY			"models/empty.mdl"

const TFTeam TFTeam_Alive = TFTeam_Red;
const TFTeam TFTeam_Dead = TFTeam_Blue;

// TF2 Mannpower Powerups
enum TFRune
{
	TFRune_Strength = 0, 
	TFRune_Haste, 
	TFRune_Regen, 
	TFRune_Defense, 
	TFRune_Vampire, 
	TFRune_Reflect, 
	TFRune_Precision, 
	TFRune_Agility, 
	TFRune_Knockout, 
	TFRune_King, 
	TFRune_Plague, 
	TFRune_Supernova
}

enum
{
	LifeState_Alive = 0,
	LifeState_Dead = 2
}

enum SolidType_t
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
};

enum struct BattleBusConfig
{
	char model[PLATFORM_MAX_PATH];
	int skin;
	float center[3];
	float diameter;
	float time;
	float height;
	float cameraOffset[3];
	float cameraAngles[3];
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, "models/props_soho/bus001.mdl");
		PrecacheModel(this.model);
		this.skin = kv.GetNum("skin");
		kv.GetVector("center", this.center);
		this.diameter = kv.GetFloat("diameter");
		this.time = kv.GetFloat("time");
		this.height = kv.GetFloat("height");
		kv.GetVector("camera_offset", this.cameraOffset);
		kv.GetVector("camera_angles", this.cameraAngles);
	}
}

enum struct LootCrateConfig
{
	float origin[3];				/**< Spawn origin */
	float angles[3];				/**< Spawn angles */
	char model[PLATFORM_MAX_PATH];	/**< World model */
	int skin;						/**< Model skin */
	char sound[PLATFORM_MAX_PATH];	/**< Sound this crate emits when opening */
	int health;						/**< Amount of damage required to open */
	float chance;					/**< Chance for this crate to spawn at all */
	//ContentType contents;			/**< Content bitflags **/
	
	void ReadConfig(KeyValues kv)
	{
		kv.GetVector("origin", this.origin);
		kv.GetVector("angles", this.angles);
		kv.GetString("model", this.model, PLATFORM_MAX_PATH, "models/props_urban/urban_crate002.mdl");
		PrecacheModel(this.model);
		this.skin = kv.GetNum("skin");
		kv.GetString("sound", this.sound, PLATFORM_MAX_PATH, "ui/itemcrate_smash_ultrarare_short.wav");
		PrecacheSound(this.sound);
		this.health = kv.GetNum("health", 125);
		this.chance = kv.GetFloat("chance", 1.0);
		// TODO: Contents, impl of this is still debateable
	}
}

methodmap LootCratesConfig < ArrayList
{
	public LootCratesConfig()
	{
		return view_as<LootCratesConfig>(new ArrayList(sizeof(LootCrateConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrateConfig lootCrate;
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

BattleBusConfig g_CurrentBattleBusConfig;
LootCratesConfig g_CurrentLootCrateConfig;

bool g_IsRoundActive;

#include "royale/player.sp"

#include "royale/battlebus.sp"
#include "royale/config.sp"
#include "royale/console.sp"
#include "royale/convar.sp"
#include "royale/event.sp"
#include "royale/loot.sp"
#include "royale/sdk.sp"
#include "royale/stocks.sp"

public void OnPluginStart()
{
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDK_Init();
	
	ConVar_Toggle(true);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	ConVar_Toggle(false);
}

public void OnMapStart()
{
	Config_Refresh();
	
	BattleBus_Precache();
	
	SDK_HookGamerules();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Client_SetTransmit);
	SDKHook(client, SDKHook_ShouldCollide, Client_ShouldCollide);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (FRPlayer(client).InBattleBus)
	{
		if (buttons & IN_JUMP)
			BattleBus_EjectClient(client);
		else
			buttons = 0;	//Don't allow client in battle bus process any other buttons
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_pipe") || StrEqual(classname, "tf_projectile_cleaver"))
	{
		SDKHook(entity, SDKHook_Touch, Projectile_Touch);
		SDKHook(entity, SDKHook_TouchPost, Projectile_TouchPost);
	}
	else if (StrContains(classname, "tf_projectile_jar") == 0)
		SDK_HookProjectile(entity);
	else if (StrContains(classname, "tf_weapon_sniperrifle") == 0 || StrEqual(classname, "tf_weapon_knife"))
		SDK_HookPrimaryAttack(entity);
	else if (StrEqual(classname, "tf_weapon_flamethrower"))
		SDK_HookFlamethrower(entity);
	else if (StrEqual(classname, "tf_gas_manager"))
		SDK_HookGasManager(entity);
}

public Action Client_SetTransmit(int entity, int client)
{
	//Don't allow teammates see invis spy
	
	if (entity == client
		 || TF2_GetClientTeam(client) <= TFTeam_Spectator
		 || TF2_IsPlayerInCondition(entity, TFCond_Bleeding)
		 || TF2_IsPlayerInCondition(entity, TFCond_Jarated)
		 || TF2_IsPlayerInCondition(entity, TFCond_Milked)
		 || TF2_IsPlayerInCondition(entity, TFCond_OnFire)
		 || TF2_IsPlayerInCondition(entity, TFCond_Gas))
	{
		return Plugin_Continue;
	}
	
	if (TF2_GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public bool Client_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if (contentsmask & CONTENTS_REDTEAM || contentsmask & CONTENTS_BLUETEAM)
		return true;
	
	return originalResult;
}

public Action Projectile_Touch(int entity, int other)
{
	//This function have team check, change projectile and owner to spectator to touch both teams
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner == other)
		return;
	
	TF2_ChangeTeam(entity, TFTeam_Spectator);
	TF2_ChangeTeam(owner, TFTeam_Spectator);
}

public void Projectile_TouchPost(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (owner == other)
		return;
	
	//Get original team by using it's weapon
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (weapon <= MaxClients)
		return;
	
	TF2_ChangeTeam(owner, TF2_GetTeam(weapon));
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Changed;
}
