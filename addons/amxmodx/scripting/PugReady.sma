#include <PugCore>
#include <PugCS>
#include <PugStocks>

#define PUG_MOD_TASK_READY_LIST 1337

new g_iPlayersMin;

new bool:g_bReady[MAX_PLAYERS+1];
new bool:g_bReadySystem;

public plugin_init()
{
	register_plugin("Pug Mod (Ready System)",PUG_MOD_VERSION,PUG_MOD_AUTHOR);

	bind_pcvar_num(get_cvar_pointer("pug_players_min"),g_iPlayersMin);
	
	register_dictionary("PugReady.txt");
	
	PUG_RegCommand("ready","PUG_Ready",ADMIN_ALL,"PUG_DESC_READY");
	PUG_RegCommand("notready","PUG_NotReady",ADMIN_ALL,"PUG_DESC_NOTREADY");
	
	PUG_RegCommand("forceready","PUG_ForceReady",ADMIN_LEVEL_A,"PUG_DESC_FORCEREADY");
}

public PUG_Event(iState)
{
	if(iState == STATE_HALFTIME)
	{
		if(PUG_GetPlayersNum(true) < g_iPlayersMin)
		{
			PUG_ReadySystem(true);
		}
	}
	else
	{
		PUG_ReadySystem(iState == STATE_WARMUP);
	}
}

PUG_ReadySystem(bool:Enable)
{
	g_bReadySystem = Enable;
	arrayset(g_bReady,false,sizeof(g_bReady));
	
	if(Enable)
	{
		set_task(0.5,"PUG_HudListReady",PUG_MOD_TASK_READY_LIST, .flags="b");
		
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_READY_START");
	}
	else
	{
		remove_task(PUG_MOD_TASK_READY_LIST);
	}
}

public PUG_HudListReady()
{	
	new szList[2][512];
	new szName[MAX_NAME_LENGTH];
	
	new iReadyCount,iPlayersCount;
	
	for(new iPlayer;iPlayer <= MaxClients;iPlayer++)
	{
		if(is_user_connected(iPlayer) && PUG_PLAYER_IN_TEAM(iPlayer))
		{
			iPlayersCount++;
			get_user_name(iPlayer,szName,charsmax(szName));
			
			if(g_bReady[iPlayer])
			{
				iReadyCount++;
				format(szList[0],charsmax(szList[]),"%s%s^n",szList[0],szName);
			}
			else
			{
				format(szList[1],charsmax(szList[]),"%s%s^n",szList[1],szName);
			}
		}
	}
	
	if(iReadyCount >= g_iPlayersMin)
	{
		PUG_ReadySystem(false);
		
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_ALL_READY");
		PUG_RunState();
	}
	else
	{
		set_hudmessage(0,255,0,0.23,0.02,0,0.0,0.6,0.0,0.0,1);
		show_hudmessage(0,"%L",LANG_PLAYER,"PUG_LIST_NOTREADY",(iPlayersCount - iReadyCount),g_iPlayersMin);
	
		set_hudmessage(0,255,0,0.58,0.02,0,0.0,0.6,0.0,0.0,2);
		show_hudmessage(0,"%L",LANG_PLAYER,"PUG_LIST_READY",iReadyCount,g_iPlayersMin);
		
		set_hudmessage(255,255,225,0.58,0.02,0,0.0,0.6,0.0,0.0,3);
		show_hudmessage(0,"^n%s",szList[0]);
	
		set_hudmessage(255,255,225,0.23,0.02,0,0.0,0.6,0.0,0.0,4);
		show_hudmessage(0,"^n%s",szList[1]);	
	}
}


public PUG_Ready(id)
{
	if(g_bReadySystem)
	{
		if(!g_bReady[id])
		{
			if(PUG_PLAYER_IN_TEAM(id))
			{
				g_bReady[id] = true;
				
				new szName[MAX_NAME_LENGTH];
				get_user_name(id,szName,charsmax(szName));
				
				client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_READY",szName);				
				return PLUGIN_HANDLED;
			}
		}
	}

	client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	
	return PLUGIN_HANDLED;
}

public PUG_NotReady(id)
{
	if(g_bReadySystem)
	{
		if(g_bReady[id])
		{
			if(PUG_PLAYER_IN_TEAM(id))
			{
				g_bReady[id] = false;
				
				new szName[MAX_NAME_LENGTH];
				get_user_name(id,szName,charsmax(szName));
				
				client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_NOTREADY",szName);
				return PLUGIN_HANDLED;
			}
		}
	}

	client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	
	return PLUGIN_HANDLED;
}

public PUG_ForceReady(id,iLevel)
{
	if(access(id,iLevel))
	{
		new szName[MAX_NAME_LENGTH];
		read_argv(1,szName,charsmax(szName));
		
		new iPlayer = cmd_target(id,szName,CMDTARGET_OBEY_IMMUNITY);
		
		if(iPlayer)
		{
			PUG_CommandClient(id,"!forceready","PUG_FORCE_READY",iPlayer,PUG_Ready(iPlayer));
		}
	}
	
	return PLUGIN_HANDLED;
}
