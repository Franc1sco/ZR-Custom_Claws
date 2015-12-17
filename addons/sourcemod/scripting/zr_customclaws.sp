#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <cstrike>
#include <sdkhooks>  

#define DATA "1.2"

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

new g_PVMid[MAXPLAYERS];

public OnPluginStart() 
{
	trie_classes = CreateTrie();
	
	HookEvent("player_spawn", OnSpawn);
	
	CreateConVar("sm_customclaws_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i)) OnClientPutInServer(i);
}

public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_PVMid[client] = Weapon_GetViewModelIndex(client, -1); 
} 

Arms(client)
{
	new cindex = ZR_GetActiveClass(client);
	//PrintToChat(client, "paso1");
	if(!ZR_IsValidClassIndex(cindex)) return;
	
	decl String:namet[64],String:model[128];
	
	new index;
	
	ZR_GetClassDisplayName(cindex, namet, sizeof(namet));
	if(!GetTrieString(trie_classes, namet, model, sizeof(model))) return;
	//PrintToChat(client, "paso2");
	if(!GetTrieValue(trie_classes, model, index)) return;
	//PrintToChat(client, "paso3");
	new wpnid = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); 
	if(wpnid < 1) return;
	SetEntProp(wpnid, Prop_Send, "m_iItemIDLow", 0);
	SetEntProp(wpnid, Prop_Send, "m_iItemIDHigh", 0);
	
	SetEntProp(wpnid, Prop_Send, "m_nModelIndex", 0); 
		
	//PrintToChat(client, "index es %i", index);
	int iWorldModel = GetEntPropEnt(wpnid, Prop_Send, "m_hWeaponWorldModel"); 
	if(IsValidEdict(iWorldModel)) SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", 0); 
	
	SetEntProp(g_PVMid[client], Prop_Send, "m_nModelIndex", index); 
}

public void OnClientPutInServer(int client)
{ 
	SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost);  
} 

public void OnClientWeaponSwitchPost(int client, int wpnid) 
{ 
    if(IsPlayerAlive(client) && ZR_IsClientZombie(client)) Arms(client);
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

// Thanks to gubka for these 2 functions below. 

// Get model index and prevent server from crash 
int Weapon_GetViewModelIndex(int client, int sIndex) 
{ 
    while ((sIndex = FindEntityByClassname2(sIndex, "predicted_viewmodel")) != -1) 
    { 
        int Owner = GetEntPropEnt(sIndex, Prop_Send, "m_hOwner"); 
        int ClientWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); 
        int Weapon = GetEntPropEnt(sIndex, Prop_Send, "m_hWeapon"); 
         
        if (Owner != client) 
            continue; 
         
        if (ClientWeapon != Weapon) 
            continue; 
         
        return sIndex; 
    } 
    return -1; 
} 
// Get entity name 
int FindEntityByClassname2(int sStartEnt, char[] szClassname) 
{ 
    while (sStartEnt > -1 && !IsValidEntity(sStartEnt)) sStartEnt--; 
    return FindEntityByClassname(sStartEnt, szClassname); 
}  
	