#pragma semicolon 1
#pragma newdecls required
#include <sdkhooks>
#include <cstrike>
#include <multicolors>

#define PLUGIN_VERSION "0.0.1"

ConVar g_cSelfRespawnEnabled;
ConVar g_cRepeatKillDetectionTime;

bool g_bSelfRespawnEnabled;
float g_fRepeatKillDetectionTime;

float g_cLastRespawnTime[MAXPLAYERS+1];
bool g_bRepeatKillDetected;

public Plugin myinfo =
{
    name = "Self respawn",
    author = "faketuna",
    description = "Respawn dead players",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart()
{
    g_cSelfRespawnEnabled             = CreateConVar("sm_self_respawn", "0.0", "Toggles self respawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cRepeatKillDetectionTime        = CreateConVar("sr_repeat_kill_time", "1.6", "If player died within this time after respawn automatically disable self respawn", FCVAR_NONE, true, 0.0, true, 10.0);

    g_cSelfRespawnEnabled.AddChangeHook(OnCvarsChanged);
    g_cRepeatKillDetectionTime.AddChangeHook(OnCvarsChanged);

    RegConsoleCmd("sm_r", Command_SelfRespawn, "respawn command");

    RegAdminCmd("sr_reset", Command_ResetState, ADMFLAG_SLAY, "sr_reset");
    RegAdminCmd("sm_enable_respawn", Command_ResetState, ADMFLAG_SLAY, "sr_reset");
    RegAdminCmd("sm_enablerespawn", Command_ResetState, ADMFLAG_SLAY, "sr_reset");

    HookEvent("round_prestart", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

    LoadTranslations("self_respawn.phrases");
}

public void SyncConVarValues() {
    g_bSelfRespawnEnabled             = GetConVarBool(g_cSelfRespawnEnabled);
    g_fRepeatKillDetectionTime        = GetConVarFloat(g_cRepeatKillDetectionTime);
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    SyncConVarValues();
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    g_bRepeatKillDetected = false;
}

public void OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    if(!g_bSelfRespawnEnabled) {
        return;
    }

    if(g_bRepeatKillDetected) {
        return;
    }

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(IsFakeClient(client)) {
        return;
    }

    char weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    if(!StrEqual(weapon, "trigger_hurt")) {
        return;
    }

    float current = GetGameTime();
    if((current - g_cLastRespawnTime[client]) <= g_fRepeatKillDetectionTime) {
        CPrintToChatAll("%t%t", "prefix", "repeat kill detected");
        g_bRepeatKillDetected = true;
    }
}

public Action Command_ResetState(int client, int args) {
    if(!g_bRepeatKillDetected) {
        CPrintToChat(client, "%t%t", "prefix", "repeat kill not detected");
        return Plugin_Handled;
    }
    g_bRepeatKillDetected = false;
    CPrintToChatAll("%t%t", "prefix", "repeat kill reset");
    return Plugin_Handled;
}

public Action Command_SelfRespawn(int client, int args) {
    if(!g_bSelfRespawnEnabled || g_bRepeatKillDetected) {
        CReplyToCommand(client, "%t%t", "prefix", "disabled");
        return Plugin_Handled;
    }

    if(!IsClientInGame(client)) {
        CReplyToCommand(client, "[SM] You need to be a player to use this command.");
        return Plugin_Handled;
    }

    if(!(2 == GetClientTeam(client)) && !(3 == GetClientTeam(client))) {
        CReplyToCommand(client, "%t%t", "prefix", "spectator");
        return Plugin_Handled;
    }

    if(IsPlayerAlive(client)) {
        CReplyToCommand(client, "%t%t", "prefix", "alive");
        return Plugin_Handled;
    }
    CS_RespawnPlayer(client);
    g_cLastRespawnTime[client] = GetGameTime();
    CReplyToCommand(client, "%t%t", "prefix", "respawn");

    return Plugin_Handled;
}