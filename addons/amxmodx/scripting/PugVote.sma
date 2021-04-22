#include <PugCore>
#include <PugCS>
#include <PugMenus>
#include <PugStocks>

new g_iPlayersMin;
new g_iFreezeTime;

new g_hRoundTime;

new g_pVoteMinPercent;
new g_pVoteKickBanTime;
new g_pVoteTimeoutTime;

new bool:g_bVoteKick[MAX_PLAYERS+1][MAX_PLAYERS+1];
new bool:g_bVotedMap[MAX_PLAYERS+1][PUG_MENU_MAPS];
new bool:g_bVotedPause[MAX_PLAYERS+1][CsTeams];
new bool:g_bPauseOnNextRound;
new bool:g_bPausedByTeam[CsTeams];
new bool:g_bVotedStop[MAX_PLAYERS+1][CsTeams];

new g_iMapCount;
new g_szMapList[PUG_MENU_MAPS][MAX_NAME_LENGTH];
new g_iMapVotes[PUG_MENU_MAPS];

public plugin_init()
{
	register_plugin("Pug Mod (Vote Vote)",PUG_MOD_VERSION,PUG_MOD_AUTHOR);
	
	register_dictionary("PugVote.txt");
	
	bind_pcvar_num(get_cvar_pointer("pug_players_min"),g_iPlayersMin);
	
	bind_pcvar_num(get_cvar_pointer("mp_freezetime"),g_iFreezeTime);
	
	disable_event(g_hRoundTime = register_event("RoundTime","HOOK_RoundTime","bc"));
	
	g_pVoteMinPercent = create_cvar("pug_vote_percent","0.7",FCVAR_NONE,"Vote percent to execute actions");
	
	g_pVoteKickBanTime = create_cvar("pug_vote_kick_ban_time","0",FCVAR_NONE,"Minutes to temporary ban if player has kicked (0 to disable)");
	
	g_pVoteTimeoutTime = create_cvar("pug_vote_timeout_time","60",FCVAR_NONE,"Seconds to pause round when timeout is running");
	
	PUG_RegCommand("vote","PUG_VoteMenu",ADMIN_ALL,"PUG_VOTE_DESC");	
}

public plugin_cfg()
{
	g_iMapCount = PUG_GetMapList(g_szMapList,sizeof(g_szMapList),get_cvar_num("pug_vote_map_stayhere"));
}

public client_putinserver(id)
{
	arrayset(g_bVotedMap[id],false,sizeof(g_bVotedMap[]));
	
	g_bVotedPause[id][CS_TEAM_T] = false;
	g_bVotedPause[id][CS_TEAM_CT] = false;
	
	g_bVotedStop[id][CS_TEAM_T] = false;
	g_bVotedStop[id][CS_TEAM_CT] = false;
	
	for(new i;i <= MaxClients;i++)
	{
		g_bVoteKick[i][id] = false;
		g_bVoteKick[id][i] = false;
	}
}

public PUG_VoteMenu(id)
{
	if(PUG_PLAYER_IN_TEAM(id))
	{
		new iMenu = menu_create("PUG_VOTE_MENU","PUG_VoteMenuHandle",true);
		
		menu_additem(iMenu,"Vote Kick","0");
		menu_additem(iMenu,"Vote Map","1");
		menu_additem(iMenu,"Vote Timeout","2");
		menu_additem(iMenu,"Vote Surrender","3");
	
		PUG_DisplayMenuSingle(id,iMenu);
	}
	
	return PLUGIN_HANDLED;
}

public PUG_VoteMenuHandle(id,iMenu,iKey)
{
	if(iKey != MENU_EXIT)
	{
		if(iKey == 0)
		{
			PUG_VoteKick(id);
		}
		else if(iKey == 1)
		{
			PUG_VoteMap(id);
		}
		else if(iKey == 2)
		{
			PUG_VoteTimeout(id);
		}
		else
		{
			PUG_VoteStop(id);
		}
	}
	
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

public PUG_VoteKick(id)
{
	new szTeam[12];
	new iTeamId = get_user_team(id,szTeam,charsmax(szTeam));
	
	if(1 <= iTeamId <= 2)
	{
		new iPlayers[MAX_PLAYERS],iNum;
		get_players(iPlayers,iNum,"e",szTeam);
		
		new iNeedPlayers = (g_iPlayersMin / 2);
		
		if(iNum >= iNeedPlayers)
		{
			new iMenu = menu_create("PUG_VOTE_KICK_MENU","HANDLER_MenuVoteKick",true);
			
			new iPlayer,szName[MAX_NAME_LENGTH];
			
			for(new i;i < iNum;i++)
			{
				iPlayer = iPlayers[i];
				
				if(iPlayer != id && !access(iPlayer,ADMIN_IMMUNITY))
				{
					get_user_name(iPlayer,szName,charsmax(szName));				

					menu_additem
					(
						iMenu,
						szName,
						fmt("%d",iPlayer), 
						.callback = g_bVoteKick[id][iPlayer] ? menu_makecallback("HANDLER_MenuPlayerDisabled") : -1
					);
				}
			}
			
			PUG_DisplayMenuSingle(id,iMenu);
			
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_KICK_MAIN");
		}
		else
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_KICK_NEED",iNeedPlayers);
		}
	}
	
	return PLUGIN_HANDLED;
}

public HANDLER_MenuPlayerDisabled()
{
	return ITEM_DISABLED;
}

public HANDLER_MenuVoteKick(id,iMenu,iKey)
{
	if(iKey != MENU_EXIT)
	{
		new szInfo[3],szOption[MAX_NAME_LENGTH];
		menu_item_getinfo(iMenu,iKey,_,szInfo,charsmax(szInfo),szOption,charsmax(szOption));
		
		new iPlayer = str_to_num(szInfo);
		
		if(is_user_connected(iPlayer))
		{
			g_bVoteKick[id][iPlayer] = true;	
			
			new iVoteCount = 0;
			
			for(new i;i <= MaxClients;i++)
			{
				if(g_bVoteKick[i][iPlayer])
				{
					iVoteCount++;
				}
			}
			
			new iVotesNeed = (PUG_GetPlayersTeam(cs_get_user_team(id)) - 1);
			new iVotesLack = (iVotesNeed - iVoteCount);
			
			if(!iVotesLack)
			{
				new iBanTime = get_pcvar_num(g_pVoteKickBanTime);
				
				if(iBanTime)
				{
					server_cmd("banid %i %i;wait;wait;writeid",iBanTime,get_user_userid(iPlayer));
					server_exec();
				}
				
				server_cmd("kick #%i ^"%L^"",get_user_userid(iPlayer),LANG_SERVER,"PUG_VOTE_KICK_MSG");
				
				client_print_color(0,iPlayer,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_KICK_KICKED",szOption,iVotesNeed);
			}
			else
			{
				new szName[MAX_NAME_LENGTH];
				get_user_name(id,szName,charsmax(szName));
				
				client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_KICK_VOTED",szName,szOption,iVotesLack);
			}
		}
	}
	
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

public PUG_VoteMap(id)
{
	if(PUG_PLAYER_IN_TEAM(id))
	{
		if(PUG_GetState() != STATE_START)
		{
			if(g_iMapCount)
			{
				new iMenu = menu_create("PUG_VOTE_MAP_MENU","HANDLER_MenuMap",true);
				
				for(new iMapIndex;iMapIndex < g_iMapCount;iMapIndex++)
				{
					menu_additem
					(
						iMenu,
						fmt("%s\R\y%i",g_szMapList[iMapIndex],g_iMapVotes[iMapIndex]),
						fmt("%i",iMapIndex),
						.callback = g_bVotedMap[id][iMapIndex] ? menu_makecallback("HANDLER_MenuMapDisabled") : -1
					);
				}
				
				PUG_DisplayMenuSingle(id,iMenu);
				client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_MAP_MAIN");
			}
		}
		else
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_MAP_VOTE");
		}
	}
	
	return PLUGIN_HANDLED;
}

public HANDLER_MenuMapDisabled()
{
	return ITEM_DISABLED;
}

public HANDLER_MenuMap(id,iMenu,iKey)
{
	if(iKey != MENU_EXIT)
	{
		new szInfo[3];
		menu_item_getinfo(iMenu,iKey,_,szInfo,charsmax(szInfo));
		
		new iMapIndex = str_to_num(szInfo);
		
		g_iMapVotes[iMapIndex]++;
		g_bVotedMap[id][iMapIndex] = true;		
		
		new iNeedVotes = floatround(g_iPlayersMin * get_pcvar_float(g_pVoteMinPercent));
		new iLackingVotes = (iNeedVotes - g_iMapVotes[iMapIndex]);
		
		if(iLackingVotes)
		{
			new szName[MAX_NAME_LENGTH];
			get_user_name(id,szName,charsmax(szName));
			
			client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_MAP_PICK1",szName,g_szMapList[iMapIndex],iLackingVotes);	
			client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_MAP_PICK2");
		}
		else
		{
			set_task(5.0,"PUG_ChangeLevel",iMapIndex);
			
			client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_MAP_CHANGE",g_szMapList[iMapIndex]);
		}
	}
	
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

public PUG_ChangeLevel(iMapIndex)
{
	engine_changelevel(g_szMapList[iMapIndex]);
}

public PUG_VoteTimeout(id)
{
	if(STATE_FIRST_HALF <= PUG_GetState() <= STATE_OVERTIME)
	{
		new CsTeams:iTeam = cs_get_user_team(id);
		
		if(CS_TEAM_T <= iTeam <= CS_TEAM_CT)
		{
			if(!g_bPausedByTeam[iTeam])
			{
				if(!g_bVotedPause[id][iTeam])
				{
					if(!g_bPauseOnNextRound)
					{
						g_bVotedPause[id][iTeam] = true;
			
						new iVoteCount = 0;
						
						for(new i;i <= MaxClients;i++)
						{	
							if(g_bVotedPause[i][iTeam])
							{
								iVoteCount++;
							}
						}
						
						new iNeedVotes = floatround(PUG_GetPlayersTeam(iTeam) * get_pcvar_float(g_pVoteMinPercent));
						new iLackingVotes = (iNeedVotes - iVoteCount);
	
						if(iLackingVotes)
						{
							new szName[MAX_NAME_LENGTH];
							get_user_name(id,szName,charsmax(szName));
							
							client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_MSG1",szName,PUG_MOD_CS_TEAMS_STR[iTeam],iLackingVotes);
							client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_MSG2");
						}
						else
						{
							g_bPauseOnNextRound = true;
							g_bPausedByTeam[iTeam] = true;
							
							enable_event(g_hRoundTime);
							
							client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_PAUSE",get_pcvar_num(g_pVoteTimeoutTime));
						}		
					}
					else
					{
						client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_PAUSE2");
					}
				}
				else
				{
					client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_VOTED");
				}
			}
			else
			{
				client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_TEAM",PUG_MOD_CS_TEAMS_STR[iTeam]);
			}
		}
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_LIVE");
	}
	
	return PLUGIN_HANDLED;
}

public HOOK_RoundTime()
{
	if(read_data(1) == g_iFreezeTime)
	{
		new iTimeout = get_pcvar_num(g_pVoteTimeoutTime);
		
		PUG_SetRoundTime(iTimeout);
		
		set_task(float(iTimeout - 1),"PUG_SetRoundTime",g_iFreezeTime); 
		
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_TIMEOUT_PAUSED",iTimeout);
		
		disable_event(g_hRoundTime);
		
		g_bPauseOnNextRound = false;
	}
}

public PUG_SetRoundTime(iTime)
{
	set_gamerules_int("CHalfLifeMultiplay","m_iRoundTimeSecs",iTime);
	set_gamerules_float("CHalfLifeMultiplay","m_fRoundCount",get_gametime());
	
	static iMsgRoundTime;
	
	if(iMsgRoundTime || (iMsgRoundTime = get_user_msgid("RoundTime")))
	{
		message_begin(MSG_ALL,iMsgRoundTime);
		write_short(iTime);
		message_end();
	}
}

public PUG_VoteStop(id)
{
	if(STATE_FIRST_HALF <= PUG_GetState() <= STATE_OVERTIME)
	{
		new CsTeams:iTeam = cs_get_user_team(id);
		
		if(CS_TEAM_T <= iTeam <= CS_TEAM_CT)
		{		
			if(!g_bVotedStop[id][iTeam])
			{
				g_bVotedStop[id][iTeam] = true;
	
				new iVoteCount = 0;
				
				for(new i;i <= MaxClients;i++)
				{	
					if(g_bVotedStop[i][iTeam])
					{
						iVoteCount++;
					}
				}
				
				new iNeedVotes = floatround(g_iPlayersMin * get_pcvar_float(g_pVoteMinPercent));
				new iLackingVotes = (iNeedVotes - iVoteCount);
	
				iLackingVotes = 0;
	
				if(iLackingVotes)
				{
					new szName[MAX_NAME_LENGTH];
					get_user_name(id,szName,charsmax(szName));
					
					client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_MSG1",szName,PUG_MOD_CS_TEAMS_STR[iTeam],iLackingVotes);
					client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_MSG2");
				}
				else
				{
					client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_END",PUG_MOD_CS_TEAMS_STR[iTeam]);
					
					PUG_SetEnded((iTeam == CS_TEAM_T) ? 2 : 1);
				}
			}
			else
			{
				client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_VOTED");
			}
		}
		else
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_TEAM");
		}
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_STOP_LIVE");
	}
}
