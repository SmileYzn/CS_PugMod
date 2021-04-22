#include <PugCore>
#include <PugStocks>
#include <PugMenus>
#include <PugCS>

#define PUG_TASK_VOTE_MAPS	2017
#define PUG_TASK_VOTE_TEAM	2018
#define PUG_TASK_HUDS_MAPS	2019
#define PUG_TASK_HUDS_TEAM	2020
#define PUG_TASK_HUDS_CAPTAIN	2021

new g_pVoteDelay;
new g_pMapVoteStayHere;
new g_pMapVoteType;
new g_pMapVote;
new g_pTeamEnforcement;
new g_pPlayersMax;

new bool:g_bVoted[MAX_PLAYERS+1];

new g_iMenuMap;
new g_iMenuTeams;

new g_iMapCount;
new g_szMapList[PUG_MENU_MAPS][MAX_NAME_LENGTH];
new g_iMapVotes[PUG_MENU_MAPS];

new g_szTeamTypes[PUG_MENU_TEAM][MAX_NAME_LENGTH];
new g_iTeamVotes[PUG_MENU_TEAM];

new g_iCaptain[2];

public plugin_init()
{
	register_plugin("Pug Mod (Menus)",PUG_MOD_VERSION,PUG_MOD_AUTHOR);
	
	register_dictionary("PugMenus.txt");
	
	g_pPlayersMax = get_cvar_pointer("pug_players_max");
	
	g_pVoteDelay = create_cvar("pug_vote_delay","15.0",FCVAR_NONE,"How long voting session goes on");
	g_pMapVoteStayHere = create_cvar("pug_vote_map_stayhere","1",FCVAR_NONE,"Add 'Stay Here' option at top of vote map to choose the current map");
	g_pMapVoteType = create_cvar("pug_vote_map_enabled","1",FCVAR_NONE,"Active vote map in pug (0 Disable, 1 Enable, 2 Random map)");
	g_pMapVote = create_cvar("pug_vote_map","0",FCVAR_NONE,"Determine if current map will have the vote map (Not used at Pug config file)")
	g_pTeamEnforcement = create_cvar("pug_teams_enforcement","0",FCVAR_NONE,"The teams method for assign teams (0 Vote, 1 Captains, 2 Random, 3 None, 4 Skill Balanced, 5 Swap Teams)");
}

public OnConfigsExecuted()
{
	g_iMenuMap  = menu_create("PUG_HUD_MAP","HANDLER_MenuVote",true);
	g_iMapCount = PUG_GetMapList(g_szMapList,sizeof(g_szMapList[]), get_pcvar_num(g_pMapVoteStayHere));

	for(new i;i < g_iMapCount;i++)
	{
		menu_additem(g_iMenuMap,g_szMapList[i],fmt("%i",i));
	}
	
	menu_setprop(g_iMenuMap,MPROP_EXIT,MEXIT_NEVER);
	
	g_iMenuTeams = menu_create("PUG_HUD_TEAM","HANDLER_MenuVote",true);
	
	formatex(g_szTeamTypes[0],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_VOTE");
	formatex(g_szTeamTypes[1],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_CAPTAIN");
	formatex(g_szTeamTypes[2],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_AUTO");
	formatex(g_szTeamTypes[3],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_NONE");
	formatex(g_szTeamTypes[4],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_SKILL");
	formatex(g_szTeamTypes[5],charsmax(g_szTeamTypes[]),"%L",LANG_SERVER,"PUG_TEAM_TYPE_SWAP");
	
	menu_additem(g_iMenuTeams,g_szTeamTypes[1],"1");
	menu_additem(g_iMenuTeams,g_szTeamTypes[2],"2");
	menu_additem(g_iMenuTeams,g_szTeamTypes[3],"3");
	menu_additem(g_iMenuTeams,g_szTeamTypes[4],"4");
	menu_additem(g_iMenuTeams,g_szTeamTypes[5],"5");
	
	menu_setprop(g_iMenuTeams,MPROP_EXIT,MEXIT_NEVER);
}

public PUG_Event(iState)
{
	if(iState == STATE_START)
	{
		new iVoteType = get_pcvar_num(g_pMapVoteType);
		
		if(get_pcvar_num(g_pMapVote) && (iVoteType > 0))
		{
			if(iVoteType == 1)
			{
				PUG_VoteStart(PUG_TASK_VOTE_MAPS);
			}
			else if(iVoteType == 2)
			{
				new szMap[MAX_NAME_LENGTH];
				get_mapname(szMap,charsmax(szMap));
				
				new StayHere = get_pcvar_num(g_pMapVoteStayHere);
				new MapIndex = random_num(StayHere, g_iMapCount);
		
				while(equali(szMap,g_szMapList[MapIndex]) || !is_map_valid(g_szMapList[MapIndex]))
				{
					MapIndex = random_num(StayHere, g_iMapCount);
				}
				
				set_pcvar_num(g_pMapVote,0);
				
				set_task(5.0,"PUG_ChangeLevel",MapIndex);
				client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTEMAP_NEXTMAP",g_szMapList[MapIndex]);
			}
		}
		else
		{
			new iEnforcement = get_pcvar_num(g_pTeamEnforcement);
			
			if(iEnforcement)
			{
				set_task(1.0,"PUG_ChangeTeams",iEnforcement);
			}
			else
			{
				PUG_VoteStart(PUG_TASK_VOTE_TEAM);
			}	
		}
	}
	else if(iState == STATE_END)
	{
		set_pcvar_num(g_pMapVote,1);
	}
}

public PUG_VoteStart(iType)
{
	arrayset(g_bVoted,false,sizeof(g_bVoted));
	
	if(iType == PUG_TASK_VOTE_MAPS)
	{
		arrayset(g_iMapVotes,0,sizeof(g_iMapVotes));
		
		PUG_DisplayMenuAll(g_iMenuMap);
		set_task(0.5,"PUG_HudList",PUG_TASK_HUDS_MAPS, .flags="b");
		
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTEMAP_START");
	}
	else
	{
		arrayset(g_iTeamVotes,0,sizeof(g_iTeamVotes));
		
		PUG_DisplayMenuAll(g_iMenuTeams);
		set_task(0.5,"PUG_HudList",PUG_TASK_HUDS_TEAM, .flags="b");
		
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMVOTE_START");
	}
	
	
	set_task(get_pcvar_float(g_pVoteDelay),"PUG_VoteEnd",iType);
}

public HANDLER_MenuVote(id,iMenu,iKey)
{
	if(iKey != MENU_EXIT)
	{
		new szNum[3],szOption[MAX_NAME_LENGTH];
		menu_item_getinfo(iMenu,iKey,_,szNum,charsmax(szNum),szOption,charsmax(szOption));
		
		new szName[MAX_NAME_LENGTH];
		get_user_name(id,szName,charsmax(szName));
	
		if(iMenu == g_iMenuMap)
		{
			g_bVoted[id] = true;
			g_iMapVotes[str_to_num(szNum)]++;
		}
		else if(iMenu == g_iMenuTeams)
		{
			g_bVoted[id] = true;
			g_iTeamVotes[str_to_num(szNum)]++;
		}
		
		client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTE_CHOOSED",szName,szOption);
		
		if(PUG_NeedStopVote())
		{
			PUG_VoteEnd((iMenu == g_iMenuMap) ? PUG_TASK_VOTE_MAPS : PUG_TASK_VOTE_TEAM);
		}
	}
	
	return PLUGIN_HANDLED;
}

PUG_NeedStopVote()
{
	new iPlayers[MAX_PLAYERS],iNum,iPlayer;
	get_players(iPlayers,iNum,"ch");
	
	for(new i;i < iNum;i++)
	{
		iPlayer = iPlayers[i];
		
		if(PUG_PLAYER_IN_TEAM(iPlayer) && !g_bVoted[iPlayer])
		{
			return false;
		}
	}
	
	return true;
}

public PUG_HudList(iType)
{
	if(iType != PUG_TASK_HUDS_CAPTAIN)
	{	
		set_hudmessage(0,255,0,0.23,0.02,0,0.0,0.7,0.0,0.0,3);
		
		new szResult[256];
		
		if(iType == PUG_TASK_HUDS_MAPS)
		{
			show_hudmessage(0,"%L",LANG_SERVER,"PUG_HUD_MAP");
			
			for(new i;i < g_iMapCount;i++)
			{
				if(g_iMapVotes[i])
				{
					format(szResult,charsmax(szResult),"%s[%i] %s^n",szResult,g_iMapVotes[i],g_szMapList[i]);
				}
			}
		}
		else
		{
			show_hudmessage(0,"%L",LANG_SERVER,"PUG_HUD_TEAM");
			
			for(new i;i < PUG_MENU_TEAM;i++)
			{
				if(g_iTeamVotes[i])
				{
					format(szResult,charsmax(szResult),"%s[%i] %s^n",szResult,g_iTeamVotes[i],g_szTeamTypes[i]);
				}
			}
		}
		
		set_hudmessage(255,255,255,0.23,0.05,0,0.0,0.7,0.0,0.0,4);
		
		if(szResult[0])
		{
			show_hudmessage(0,szResult);
		}
		else
		{
			show_hudmessage(0,"%L",LANG_SERVER,"PUG_NOVOTES");
		}
	}
	else
	{
		new iPlayers[MAX_PLAYERS],iNum,iPlayer;
		get_players(iPlayers,iNum,"h");
		
		new szName[MAX_NAME_LENGTH],szList[4][320],iTeam;
		new iCountSpecs,iCountCTs;
	
		for(new i;i < iNum;i++)
		{
			iPlayer = iPlayers[i];
			
			get_user_name(iPlayer,szName,charsmax(szName));
			
			if((iPlayer == g_iCaptain[0]) || (iPlayer == g_iCaptain[1]))
			{
				add(szName,charsmax(szName)," (C)");
			}
			
			iTeam = get_user_team(iPlayer);
			
			if(iTeam == 2)
			{
				iCountCTs++;
			}
			else if(iTeam == 3)
			{
				iCountSpecs++;
			}
			
			add(szName,charsmax(szName),"^n");
			add(szList[iTeam],charsmax(szList[]),szName);
		}
		
		for(new i = 0;i < 5 - iCountCTs;i++)
		{
			add(szList[2],charsmax(szList[]),"^n");
		}
	
		set_hudmessage(0,255,0,0.75,0.02,0,0.0,99.0,0.0,0.0,1);
		show_hudmessage(0,"Terrorists");
		
		set_hudmessage(255,255,255,0.75,0.02,0,0.0,99.0,0.0,0.0,2);
		show_hudmessage(0,"^n%s",szList[1]);
	
		if(iCountSpecs)
		{
			set_hudmessage(0,255,0,0.75,0.28,0,0.0,99.0,0.0,0.0,3);
			show_hudmessage(0,"CTs^n^n^n^n^n^n%L",LANG_SERVER,"PUG_CAPTAINS_UNASSIGNED");
			
			set_hudmessage(255,255,255,0.75,0.28,0,0.0,99.0,0.0,0.0,4);
			show_hudmessage(0,"^n%s^n%s",szList[2],szList[3]);
		}
		else
		{
			set_hudmessage(0,255,0,0.75,0.28,0,0.0,99.0,0.0,0.0,3);
			show_hudmessage(0,"CTs");
			
			set_hudmessage(255,255,255,0.75,0.28,0,0.0,99.0,0.0,0.0,4);
			show_hudmessage(0,"^n%s",szList[2]);
		}
	}
	
}

public PUG_VoteEnd(iType)
{
	PUG_CancelMenu(0);
	remove_task(iType);
	
	if(!PUG_GetVoteCount(iType))
	{
		set_task(get_pcvar_float(g_pVoteDelay),"PUG_VoteStart",iType);
	}
	
	remove_task(PUG_TASK_HUDS_MAPS);
	remove_task(PUG_TASK_HUDS_TEAM);
}

PUG_GetVoteCount(iType)
{
	if(iType == PUG_TASK_VOTE_MAPS)
	{
		new iWinner,iWinnerVotes,iVotes;
	
		for(new i;i < g_iMapCount;i++)
		{
			iVotes = g_iMapVotes[i];
			
			if(iVotes > iWinnerVotes)
			{
				iWinner = i;
				iWinnerVotes = iVotes;
			}
			else if(iVotes == iWinnerVotes)
			{
				if(random_num(0,1))
				{
					iWinner = i;
					iWinnerVotes = iVotes;
				}
			}
		}
	
		if(!g_iMapVotes[iWinner])
		{
			client_print_color(0,print_team_red,"%s %L %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTEMAP_FAIL",LANG_SERVER,"PUG_NOVOTES");
			return 0;
		}
	
		set_pcvar_num(g_pMapVote,0);

		if(get_pcvar_num(g_pMapVoteStayHere) && (iWinner == 0))
		{
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTEMAP_STAYHERE_WIN");
			set_task(5.0, "PUG_Event", PUG_GetState());
		}
		else
		{
			set_task(5.0,"PUG_ChangeLevel",iWinner);
		
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_VOTEMAP_NEXTMAP",g_szMapList[iWinner]);
		}
		
		return g_iMapVotes[iWinner];
	}
	else
	{
		new iWinner,iWinnerVotes,iVotes;
	
		for(new i;i < sizeof(g_iTeamVotes);i++)
		{
			iVotes = g_iTeamVotes[i];
			
			if(iVotes > iWinnerVotes)
			{
				iWinner = i;
				iWinnerVotes = iVotes;
			}
			else if(iVotes == iWinnerVotes)
			{
				if(random_num(0,1))
				{
					iWinner = i;
					iWinnerVotes = iVotes;
				}
			}
		}

		if(!g_iTeamVotes[iWinner])
		{
			client_print_color(0,print_team_red,"%s %L %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMVOTE_FAIL",LANG_SERVER,"PUG_NOVOTES");
			return 0;
		}
		
		PUG_ChangeTeams(iWinner);
		
		return g_iTeamVotes[iWinner];
	}
}

public PUG_ChangeLevel(iMapIndex)
{
	engine_changelevel(g_szMapList[iMapIndex]);
}

public PUG_ChangeTeams(iType)
{
	switch(iType)
	{
		case 1:
		{
			new iPlayers[MAX_PLAYERS],iNum;
			get_players(iPlayers,iNum,"h");
			
			if(iNum >= PUG_CAPTAIN_PLAYERS)
			{
				new iPlayer;
				
				g_iCaptain[0] = iPlayers[random(iNum)];
				g_iCaptain[1] = iPlayers[random(iNum)];
				
				while(g_iCaptain[0] == g_iCaptain[1] || is_user_bot(g_iCaptain[0]))
				{
					g_iCaptain[0] = iPlayers[random(iNum)];
				}				
				
				cs_set_user_team(g_iCaptain[0],CS_TEAM_T);
				cs_set_user_team(g_iCaptain[1],CS_TEAM_CT);
				
				new szName[2][MAX_NAME_LENGTH];
				get_user_name(g_iCaptain[0],szName[0],charsmax(szName[]));
				get_user_name(g_iCaptain[1],szName[1],charsmax(szName[]));
				
				client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_CAPTAINS_ARE",szName[0],szName[1]);
				
				for(new i;i < iNum;i++)
				{
					iPlayer = iPlayers[i];
					
					if(g_iCaptain[0] != iPlayer && g_iCaptain[1] != iPlayer)
					{
						user_silentkill(iPlayer);
						cs_set_user_team(iPlayer,CS_TEAM_SPECTATOR);	
					}
				}
				
				
				
				set_task(0.5,"PUG_HudList",PUG_TASK_HUDS_CAPTAIN, .flags="b");
				set_task(2.0,"PUG_CaptainMenu",g_iCaptain[random_num(0,1)]);
			}
			else
			{
				PUG_RunState();
			}
		}
		case 2:
		{
			PUG_TeamsRandomize();
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMS_RANDOM");
			
			PUG_RunState();
		}
		case 3:
		{
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMS_SAME");
			
			PUG_RunState();
		}
		case 4:
		{
			PUG_TeamsOptimize();
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMS_SKILL");
			
			PUG_RunState();
		}
		case 5:
		{
			PUG_TeamsSwap();
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_TEAMS_SWAP");
			
			PUG_RunState();
		}
	}
}

public PUG_CaptainMenu(id)
{
	new iPlayers[MAX_PLAYERS],iNum,iPlayer;
	get_players(iPlayers,iNum,"eh","SPECTATOR");
	
	if((!is_user_connected(id) || !PUG_PLAYER_IN_TEAM(id)) && (iNum > 0))
	{
		iPlayer = iPlayers[random(iNum)];
		
		new szName[MAX_NAME_LENGTH];
		get_user_name(iPlayer,szName,charsmax(szName));
		
		if(id == g_iCaptain[0])
		{
			g_iCaptain[0] = iPlayer;
			
			PUG_SetTeamAndRespawn(iPlayer,CS_TEAM_T);
			
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_CAPTAINS_NEW_T",szName);
		}
		else if(id == g_iCaptain[1])
		{
			g_iCaptain[1] = iPlayer;
			
			PUG_SetTeamAndRespawn(iPlayer,CS_TEAM_CT);
			
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_CAPTAINS_NEW_CT",szName);
		}
		
		set_task(2.0,"PUG_CaptainMenu",iPlayer);
	}
	else
	{
		if(iNum && (PUG_GetPlayersNum(true) < get_pcvar_num(g_pPlayersMax)))
		{
			if(is_user_bot(id))
			{
				PUG_CaptainPickUpRandom(id);
			}
			else
			{
				PUG_CancelMenu(id);
				
				new iMenu = menu_create("Players:","PUG_MenuHandler");
				
				new szName[MAX_NAME_LENGTH];
				
				for(new i;i < iNum;i++)
				{
					iPlayer = iPlayers[i];
					
					get_user_name(iPlayer,szName,charsmax(szName));
					
					menu_additem(iMenu,szName,fmt("%i",iPlayer));
				}
				
				menu_setprop(iMenu,MPROP_EXIT,MEXIT_NEVER);
				
				PUG_DisplayMenuSingle(id,iMenu);
				
				set_task(10.0,"PUG_CaptainPickUpRandom",id);
			}
		}
		else
		{
			remove_task(PUG_TASK_HUDS_CAPTAIN);
			PUG_RunState();
		}
	}
}

public PUG_MenuHandler(id,iMenu,iKey)
{
	if(iKey != MENU_EXIT)
	{
		if(is_user_connected(id))
		{
			new szNum[3],szOption[MAX_NAME_LENGTH];
			menu_item_getinfo(iMenu,iKey,_,szNum,charsmax(szNum),szOption,charsmax(szOption));
			
			new iPlayer = str_to_num(szNum);
			
			if(is_user_connected(iPlayer))
			{
				remove_task(id);
				
				PUG_SetTeamAndRespawn(iPlayer,cs_get_user_team(id));
				
				new szName[MAX_NAME_LENGTH];
				get_user_name(id,szName[0],charsmax(szName));
				
				client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_CAPTAINS_PICK",szName,szOption);
			}
		}
		
		set_task(2.0,"PUG_CaptainMenu",(id == g_iCaptain[0]) ? g_iCaptain[1] : g_iCaptain[0]);
	}
	
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

public PUG_CaptainPickUpRandom(id)
{
	if(is_user_connected(id))
	{
		if(PUG_PLAYER_IN_TEAM(id))
		{
			PUG_CancelMenu(id);
		
			new iPlayers[MAX_PLAYERS],iNum;
			get_players(iPlayers,iNum,"eh","SPECTATOR");
		
			if(iNum)
			{
				new iPlayer = iPlayers[random(iNum)];
				
				if(is_user_connected(iPlayer))
				{
					PUG_SetTeamAndRespawn(iPlayer,cs_get_user_team(id));
					
					new szName[2][MAX_NAME_LENGTH];
					get_user_name(id,szName[0],charsmax(szName[]));
					get_user_name(iPlayer,szName[1],charsmax(szName[]));					
					
					client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_SERVER,"PUG_CAPTAINS_PICK",szName[0],szName[1]);
				}
				
				set_task(2.0,"PUG_CaptainMenu",(id == g_iCaptain[0]) ? g_iCaptain[1] : g_iCaptain[0]);
			}
			else
			{
				remove_task(PUG_TASK_HUDS_CAPTAIN);
				PUG_RunState();
			}
		}
		else
		{
			PUG_CaptainMenu(id);
		}
	}
}

PUG_SetTeamAndRespawn(id,CsTeams:iTeam)
{
	if(pev_valid(id) == 2)
	{
		if(!PUG_PLAYER_IN_TEAM(id))
		{
			set_ent_data(id,"CBasePlayer","m_iJoiningState",CS_STATE_GET_INTO_GAME);
			
			set_ent_data(id,"CBasePlayer","m_iTeam",(iTeam == CS_TEAM_T) ? 1 : 2);
		}	
				
		cs_set_user_team(id,iTeam);
		
		set_pev(id,pev_deadflag,DEAD_RESPAWNABLE);
		
		ExecuteHamB(Ham_CS_RoundRespawn,id);
	}
}
