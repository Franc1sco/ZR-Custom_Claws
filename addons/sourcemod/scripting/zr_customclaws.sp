#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <cstrike>
#include <sdkhooks>  
#include <fpvm_interface>

#define DATA "2.0"

public Plugin:myinfo =
{
	name = "ZR Custom CS:GO Claws",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

new Handle:kv;
new Handle:hPlayerClasses, String:sClassPath[PLATFORM_MAX_PATH] = "configs/zr/playerclasses.txt";

new Handle:trie_classes;

int saved[MAXPLAYERS+1][2];

public OnPluginStart() 
{
	trie_classes = CreateTrie();
	
	HookEvent("player_spawn", OnSpawn, EventHookMode_Pre);
	
	CreateConVar("sm_customclaws_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public FPVMI_OnClientViewModel(client, const String:name[], weapon_index)
{
	if(StrEqual(name, "weapon_knife"))
	{
		if(ZR_IsClientHuman(client)) saved[client][0] = weapon_index;
	}
}

public FPVMI_OnClientWorldModel(client, const String:name[], weapon_index)
{
	if(StrEqual(name, "weapon_knife"))
	{
		if(ZR_IsClientHuman(client)) saved[client][1] = weapon_index;
	}
}

public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(2.0, pasado, GetClientUserId(client));
	//Arms(client);
}

public Action pasado(Handle timer, int userid)
{
	new client = GetClientOfUserId(userid);
	if(client != 0) Arms(client);
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	Arms(client);
}

public ZR_OnClientHumanPost(client, bool:respawn, bool:protect)
{
	Arms(client);
}

Arms(client)
{
	if(ZR_IsClientHuman(client))
	{
		FPVMI_SetClientModel(client, "weapon_knife", saved[client][0]==0?-1:saved[client][0], saved[client][1]==0?-1:saved[client][1]);
		return;
	}
	new cindex = ZR_GetActiveClass(client);
	//PrintToChat(client, "paso1");
	if(!ZR_IsValidClassIndex(cindex)) return;
	
	decl String:namet[64],String:model[128];
	
	new index;
	
	ZR_GetClassDisplayName(cindex, namet, sizeof(namet));
	if(!GetTrieString(trie_classes, namet, model, sizeof(model)))
	{
		return;
	}
	//PrintToChat(client, "paso2");
	if(GetTrieValue(trie_classes, model, index)) 
		FPVMI_AddViewModelToClient(client, "weapon_knife", index);
}
//

public OnAllPluginsLoaded()
{
	if (hPlayerClasses != INVALID_HANDLE)
	{
		UnhookConVarChange(hPlayerClasses, OnClassPathChange);
		CloseHandle(hPlayerClasses);
	}
	if ((hPlayerClasses = FindConVar("zr_config_path_playerclasses")) == INVALID_HANDLE)
	{
		SetFailState("Zombie:Reloaded is not running on this server");
	}
	HookConVarChange(hPlayerClasses, OnClassPathChange);
}

public OnClassPathChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	strcopy(sClassPath, sizeof(sClassPath), newValue);
	OnMapStart();
}

public OnMapStart()
{
	PrecacheModel("models/zombie/normal_f/hand/hand_zombie_normal_f_ani.mdl");
	PrecacheModel("models/zombie/normalhost_female/hand/hand_zombie_normalhost_f_ani.mdl");	
	PrecacheModel("models/zombie/normal/hand/hand_zombie_normal_ani.mdl");
	PrecacheModel("models/zombie/normalhost/hand/hand_zombie_normalhost_ani.mdl");
	
	AddFileToDownloadsTable("models/zombie/normal_f/hand/hand_zombie_normal_f_ani.mdl");
	AddFileToDownloadsTable("models/zombie/normalhost_female/hand/hand_zombie_normalhost_f_ani.mdl");	
	AddFileToDownloadsTable("models/zombie/normal/hand/hand_zombie_normal_ani.mdl");
	AddFileToDownloadsTable("models/zombie/normalhost/hand/hand_zombie_normalhost_ani.mdl");
	
	if (kv != INVALID_HANDLE)
	{
		CloseHandle(kv);
	}
	kv = CreateKeyValues("classes");
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s", sClassPath);
	
	if (!FileToKeyValues(kv, buffer))
	{
		SetFailState("Class data file \"%s\" not found", buffer);
	}
	new index;
	if (KvGotoFirstSubKey(kv))
	{
		ClearTrie(trie_classes);
		decl String:name[64],String:model[128];
		
		do
		{
			KvGetString(kv, "name", name, sizeof(name));
			KvGetString(kv, "claws_path", model, sizeof(model), " ");
			
			SetTrieString(trie_classes, name, model);
			
			if(strlen(model) > 3 && FileExists(model) && !IsModelPrecached(model)) 
			{
				index = PrecacheModel(model);
				SetTrieValue(trie_classes, model, index);
				PrintToServer("Loaded model %s with index %i", model, index);
			}
			
		} while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}
	