#include <PugCore>
#include <PugStocks>
#include <PugCS>

new g_iEvent;
new g_iState;

new g_pPlayersMin;
new g_pPlayersMax;

new g_pMaxRounds;
new g_pMaxRoundsOT;
new g_pForceOT;

new g_pAllowSpec;
new g_pAllowHLTV;

new g_pHandleTime;
new g_pBanLeaveTime;

new g_iRounds;
new g_iScores[CsTeams];
new g_szTeams[CsTeams][MAX_NAME_LENGTH] = {"Unassigned","Terrorists","Counter-Terrorists","Spectators"};
new g_iFrags[MAX_PLAYERS+1][2];

new g_iMsgTeamScore;
new g_iMsgScoreInfo;

new g_hLogEventRoundStart;
new g_hLogEventRoundEnd;

new g_hEventRound;
new g_hEventTextMsg;

public plugin_init()
{
	register_plugin(PUG_MOD_PLUGIN,PUG_MOD_VERSION,PUG_MOD_AUTHOR);
	
	register_dictionary("common.txt");
	register_dictionary("PugCore.txt");
	
	g_iEvent = CreateMultiForward("PUG_Event",ET_IGNORE,FP_CELL);
	
	g_pPlayersMin = create_cvar("pug_players_min","10",FCVAR_NONE,"Minimum of players to start a game");
	g_pPlayersMax = create_cvar("pug_players_max","10",FCVAR_NONE,"Maximum of players allowed in the teams");
	
	g_pMaxRounds = create_cvar("pug_rounds_max","30",FCVAR_NONE,"Rounds to play before start overtime");
	g_pMaxRoundsOT = create_cvar("pug_rounds_ot","3",FCVAR_NONE,"Win difference to determine a winner in overtime");
	g_pForceOT = create_cvar("pug_force_ot","1",FCVAR_NONE,"Force Overtime (0 End tied, 1 Force Overtime)");
	
	g_pAllowSpec = create_cvar("pug_allow_spec","1",FCVAR_NONE,"Allow Spectators in game");
	g_pAllowHLTV = create_cvar("pug_allow_hltv","1",FCVAR_NONE,"Allow HLTV in game");
	
	g_pHandleTime = create_cvar("pug_handle_time","10.0",FCVAR_NONE,"Time to PUG change states");
	
	g_pBanLeaveTime	= create_cvar("pug_drop_ban_time","15",FCVAR_NONE,"Minutes of ban players that leave from game in live");
	
	register_clcmd("say","HOOK_SayHandler");
	register_clcmd("say_team","HOOK_SayHandler");
	
	PUG_RegCommand("status","PUG_Status",ADMIN_ALL,"PUG_DESC_STATUS");
	PUG_RegCommand("score","PUG_ShowScore",ADMIN_ALL,"PUG_DESC_SCORE");
	
	PUG_RegCommand("startpug","PUG_StartPug",ADMIN_LEVEL_A,"PUG_DESC_START");
	PUG_RegCommand("stoppug","PUG_StopPug",ADMIN_LEVEL_A,"PUG_DESC_STOP");
	
	PUG_RegCommand("help","PUG_Help",ADMIN_ALL,"PUG_DESC_HELP");
	PUG_RegCommand("help","PUG_HelpAdmin",ADMIN_LEVEL_A,"PUG_DESC_HELP_ADMIN");
	
	disable_logevent(g_hLogEventRoundStart = register_logevent("HOOK_RoundStart",2,"1=Round_Start"));
	disable_logevent(g_hLogEventRoundEnd = register_logevent("HOOK_RoundEnd",2,"1=Round_End"));
	
	disable_event(g_hEventRound = register_event("SendAudio","HOOK_Round","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw"));
	disable_event(g_hEventTextMsg = register_event("TextMsg","HOOK_RoundRestart","a","2=#Game_will_restart_in"));
	
	register_clcmd("jointeam","HOOK_JoinTeamHandle");
	
	register_clcmd("joinclass","HOOK_JoinedClass");
	register_clcmd("menuselect","HOOK_JoinedClass");
	
	register_menucmd(-2,MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_6,"HOOK_TeamSelectHandle");
	register_menucmd(register_menuid("Team_Select",1),MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_6,"HOOK_TeamSelectHandle");
}

public plugin_natives()
{
	register_library("PugCore");
	
	register_native("PUG_RunState","PUG_Next");
	
	register_native("PUG_GetState","PUG_GetStates");
	register_native("PUG_GetScore","PUG_GetScores");
	register_native("PUG_GetRound","PUG_GetRounds");
}

public plugin_cfg()
{
	PUG_BuildHelpFile(ADMIN_ALL);
	PUG_BuildHelpFile(ADMIN_LEVEL_A);
	
	set_task(5.0,"PUG_Next");
}

public plugin_end()
{
	if(STATE_FIRST_HALF <= g_iState <= STATE_OVERTIME)
	{
		g_iState = STATE_END;
		ExecuteForward(g_iEvent,_,g_iState);
	}
}

public client_connectex(id,const szName[],const szIP[],szReason[128])
{	
	if(!is_user_hltv(id))
	{
		if(!get_pcvar_num(g_pAllowSpec))
		{
			if(PUG_GetPlayersNum(true) >= get_pcvar_num(g_pPlayersMax))
			{
				formatex(szReason,charsmax(szReason),"%L",LANG_SERVER,"PUG_KICK_MSG_FULL");
				return PLUGIN_HANDLED;
			}
		}
	}
	else
	{
		if(!get_pcvar_num(g_pAllowHLTV))
		{
			formatex(szReason,charsmax(szReason),"%L",LANG_SERVER,"PUG_KICK_MSG_HLTV");
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public client_disconnected(id,bool:bDrop,szReason[],iLen)
{
	if(STATE_FIRST_HALF <= g_iState <= STATE_OVERTIME)
	{
		if(bDrop)
		{
			if(!is_user_hltv(id))
			{
				if(get_playersnum() < get_pcvar_num(g_pPlayersMin) / 2)
				{
					g_iState = STATE_END;
					ExecuteForward(g_iEvent,_,g_iState);
				}
				else
				{
					if(1 <= get_user_team(id) <= 2)
					{
						new iBanTime = get_pcvar_num(g_pBanLeaveTime);
						
						if(iBanTime)
						{
							if(equali(szReason,"Timed out") || equali(szReason,"Client sent 'drop'"))
							{
								if(!access(id,ADMIN_LEVEL_A))
								{
									new szAuth[MAX_AUTHID_LENGTH];
									get_user_authid(id,szAuth,charsmax(szAuth));
									
									new szName[MAX_NAME_LENGTH];
									get_user_name(id,szName,charsmax(szName));
									
									server_cmd("banid %i %s;wait;writeid",iBanTime,szAuth);
									
									client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_CLIENT_DROP_BAN",szName,iBanTime,szReason);
								}
							}
						}	
					}
				}
			}	
		}
	}
}

public PUG_Next()
{
	switch(g_iState)
	{
		case STATE_DEAD:
		{			
			g_iState = STATE_WARMUP;
		}
		case STATE_WARMUP:
		{
			g_iState = STATE_START;
		}
		case STATE_START:
		{
			g_iState = STATE_FIRST_HALF;
		}
		case STATE_FIRST_HALF:
		{
			g_iState = STATE_HALFTIME;
		}
		case STATE_HALFTIME:
		{
			g_iState = (g_iRounds < get_pcvar_num(g_pMaxRounds)) ? STATE_SECOND_HALF : STATE_OVERTIME;
		}
		case STATE_SECOND_HALF:
		{
			if(g_iRounds == get_pcvar_num(g_pMaxRounds))
			{
				if(get_pcvar_num(g_pForceOT))
				{
					g_iState = STATE_HALFTIME;
				}
				else
				{
					g_iState = STATE_END;
				}
			}
			else
			{
				g_iState = STATE_END;
			}
		}
		case STATE_OVERTIME:
		{
			if((g_iRounds % get_pcvar_num(g_pMaxRoundsOT)) == 0)
			{
				g_iState = STATE_HALFTIME;
			}
			else
			{
				g_iState = STATE_END;
			}
		}
		case STATE_END:
		{
			g_iState = STATE_WARMUP;
		}
	}
	
	ExecuteForward(g_iEvent,_,g_iState);
}

public PUG_GetStates()
{
	return g_iState;
}

public PUG_GetScores()
{
	return g_iScores[CsTeams:get_param(1)];
}

public PUG_GetRounds()
{
	return g_iRounds;
}

public PUG_Event(iState)
{
	switch(iState)
	{
		case STATE_WARMUP:
		{
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_WARMUP_MSG");
		}
		case STATE_FIRST_HALF:
		{			
			PUG_LO3(1);
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_LIVE_1ST");
		}
		case STATE_HALFTIME:
		{
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_HALFTIME");
			
			set_task(get_pcvar_float(g_pHandleTime),"PUG_SwapTeams");
		}
		case STATE_SECOND_HALF:
		{
			PUG_LO3(1);
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_LIVE_2ND");
		}
		case STATE_OVERTIME:
		{
			PUG_LO3(1);
			client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_LIVE_OT");
		}
		case STATE_END:
		{
			PUG_DisplayScores(0,true);
			set_task(get_pcvar_float(g_pHandleTime),"PUG_Next");
			
		}
	}
	
	if(iState == STATE_FIRST_HALF || iState == STATE_SECOND_HALF || iState == STATE_OVERTIME)
	{
		g_iMsgTeamScore = register_message(get_user_msgid("TeamScore"),"HOOK_TeamScore");
		g_iMsgScoreInfo = register_message(get_user_msgid("ScoreInfo"),"HOOK_ScoreInfo");
		
		enable_logevent(g_hLogEventRoundStart);
		enable_logevent(g_hLogEventRoundEnd);
		
		enable_event(g_hEventRound);
		enable_event(g_hEventTextMsg);
	}
	else
	{
		unregister_message(get_user_msgid("TeamScore"),g_iMsgTeamScore);
		unregister_message(get_user_msgid("ScoreInfo"),g_iMsgScoreInfo);
		
		disable_logevent(g_hLogEventRoundStart);
		disable_logevent(g_hLogEventRoundEnd);
		
		disable_event(g_hEventRound);
		disable_event(g_hEventTextMsg);
	}
}

public HOOK_SayHandler(id)
{
	new szArgs[192];
	read_args(szArgs,charsmax(szArgs));
	remove_quotes(szArgs);
	
	if((szArgs[0] == '.') || (szArgs[0] == '!'))
	{
		client_cmd(id,szArgs);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public PUG_Status(id)
{
	client_print_color
	(
		id,
		id,
		"%s %L",
		PUG_MOD_HEADER,
		id,
		"PUG_STATUS",
		PUG_MOD_STATES_STR[g_iState],
		get_playersnum(),
		get_pcvar_num(g_pPlayersMin),
		get_pcvar_num(g_pPlayersMax)
	);	
	
	return PLUGIN_HANDLED;
}

public PUG_ShowScore(id)
{
	if(STATE_FIRST_HALF <= g_iState <= STATE_OVERTIME)
	{
		PUG_DisplayScores(id);
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	}
	
	return PLUGIN_HANDLED;
}

public PUG_StartPug(id,iLevel)
{
	if(access(id,iLevel))
	{
		new bool:bCheck = (g_iState == STATE_WARMUP || g_iState == STATE_HALFTIME);
		
		PUG_ExecuteCommand(id,"!startpug","PUG_START_PUG",bCheck);
		
		if(bCheck)
		{
			PUG_Next();			
		}
	}
	
	return PLUGIN_HANDLED;
}

public PUG_StopPug(id,Level)
{
	if(access(id,Level) || (id == 0))
	{
		new bool:bCheck = (STATE_FIRST_HALF <= g_iState <= STATE_OVERTIME);
		
		PUG_ExecuteCommand(id,"!stoppug","PUG_STOP_PUG",bCheck);
		
		if(bCheck)
		{
			g_iState = STATE_END;
			ExecuteForward(g_iEvent,_,g_iState);
			
		}
	}
	
	return PLUGIN_HANDLED;
}

public PUG_Help(id)
{
	new szPath[64];
	PUG_GetFilePath("help.htm",szPath,charsmax(szPath));
	
	new szTitle[MAX_NAME_LENGTH];
	format(szTitle,charsmax(szTitle),"%L",id,"PUG_HELP_TITLE");

	show_motd(id,szPath,szTitle);
	
	return PLUGIN_HANDLED;
}

public PUG_HelpAdmin(id,Level)
{
	if(access(id,Level))
	{
		new szPath[64];
		PUG_GetFilePath("admin.htm",szPath,charsmax(szPath));
		
		new szTitle[MAX_NAME_LENGTH];
		format(szTitle,charsmax(szTitle),"%L",id,"PUG_HELP_TITLE_ADMIN");
	
		show_motd(id,szPath,szTitle);
	}
	
	return PLUGIN_HANDLED;
}

public PUG_LO3(iDelay)
{
	switch(iDelay)
	{
		case 1:
		{
			set_task(2.0,"PUG_LO3",iDelay+1);
			set_cvar_num("sv_restart",iDelay);
		}
		case 2:
		{
			set_task(3.0,"PUG_LO3",iDelay+1);
			set_cvar_num("sv_restart",iDelay);
		}
		case 3:
		{
			set_task(4.0,"PUG_LO3",iDelay+1);
			set_cvar_num("sv_restart",iDelay);
		}
		default:
		{
			set_hudmessage(0,255,0,-1.0,0.3,0,6.0,6.0);
			show_hudmessage(0,"%L",LANG_PLAYER,"PUG_LIVE_HUD_MSG");
		}
	}
}

PUG_DisplayScores(id,bool:bEnded = false)
{
	new CsTeams:iWinner = PUG_GetWinner();
	
	if(iWinner)
	{
		client_print_color
		(
			id,
			(iWinner == CS_TEAM_T) ? print_team_red : print_team_blue,
			"%s %L",
			PUG_MOD_HEADER,
			id,
			bEnded ? "PUG_END_WONALL" : "PUG_SCORE",
			g_szTeams[iWinner],
			g_iScores[iWinner],
			g_iScores[iWinner == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T]
		);
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,bEnded ? "PUG_END_TIED" : "PUG_SCORE_TIED",g_iScores[CS_TEAM_T],g_iScores[CS_TEAM_T]);
	}
}

CsTeams:PUG_GetWinner()
{
	if(g_iScores[CS_TEAM_T] != g_iScores[CS_TEAM_CT])
	{
		return (g_iScores[CS_TEAM_T] > g_iScores[CS_TEAM_CT]) ? CS_TEAM_T : CS_TEAM_CT;
	}
	
	return CS_TEAM_UNASSIGNED;
}

public PUG_SwapTeams()
{
	new iScoreTR 		= g_iScores[CS_TEAM_T];
	g_iScores[CS_TEAM_T] 	= g_iScores[CS_TEAM_CT];
	g_iScores[CS_TEAM_CT] 	= iScoreTR;

	PUG_TeamsSwap();
	set_cvar_num("sv_restart",1);
	
	if(PUG_GetPlayersNum(true) >= get_pcvar_num(g_pPlayersMin))
	{
		PUG_Next();
	}
}

public HOOK_TeamScore()
{
	new szTeam[2];
	get_msg_arg_string(1,szTeam,charsmax(szTeam));

	set_msg_arg_int(2,ARG_SHORT,g_iScores[(szTeam[0] == 'T') ? CS_TEAM_T : CS_TEAM_CT]);
}

public HOOK_ScoreInfo(iMsg,iDest)
{
	if(iDest == MSG_ALL || iDest == MSG_BROADCAST)
	{
		if(get_msg_arg_int(5)) 
		{
			new id = get_msg_arg_int(1); 
			
			if(is_user_connected(id))
			{
				set_msg_arg_int(2,ARG_SHORT,get_msg_arg_int(2) + g_iFrags[id][0]);
				set_msg_arg_int(3,ARG_SHORT,get_msg_arg_int(3) + g_iFrags[id][1]);
			}
		}
	}
}

public HOOK_Round()
{
	new szCode[32];
	read_data(2,szCode,charsmax(szCode));

	if(containi(szCode,"MRAD_rounddraw") != -1)
	{
		client_print_color(0,print_team_red,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_ROUND_DRAW",g_iRounds);
	}
	else
	{
		new CsTeams:iWinner = (containi(szCode,"MRAD_terwin") != -1) ? CS_TEAM_T : CS_TEAM_CT;
		
		g_iRounds++;
		g_iScores[iWinner]++;
		client_print(0,print_console,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_ROUND_WON",g_iRounds,g_szTeams[iWinner]);
	}
}

public HOOK_RoundStart()
{
	if(g_iRounds)
	{
		PUG_DisplayScores(0);
	}

	client_print(0,print_console,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,"PUG_ROUND_START",(g_iRounds + 1));
}

public HOOK_RoundEnd()
{
	if(g_iState == STATE_FIRST_HALF)
	{
		if(g_iRounds == (get_pcvar_num(g_pMaxRounds) / 2))
		{
			set_task(2.0,"PUG_Next");
		}
	}
	else if(g_iState == STATE_SECOND_HALF)
	{
		new iHalfRounds = (get_pcvar_num(g_pMaxRounds) / 2);
		
		if(g_iScores[PUG_GetWinner()] > iHalfRounds)
		{
			set_task(2.0,"PUG_Next");
		}
		else if((g_iScores[CS_TEAM_T] == iHalfRounds) && (g_iScores[CS_TEAM_CT] == iHalfRounds))
		{
			set_task(2.0,"PUG_Next");
		}
	}
	else if(g_iState == STATE_OVERTIME)
	{
		new iRounds = get_pcvar_num(g_pMaxRoundsOT);
		
		if((g_iRounds % iRounds) == 0)
		{
			set_task(2.0,"PUG_Next");
		}
		else if((g_iScores[CS_TEAM_T] - g_iScores[CS_TEAM_CT]) > iRounds)
		{
			set_task(2.0,"PUG_Next");
		}
		else if((g_iScores[CS_TEAM_CT] - g_iScores[CS_TEAM_T]) > iRounds)
		{
			set_task(2.0,"PUG_Next");
		}
	}
}

public HOOK_RoundRestart()
{
	if(g_iState == STATE_FIRST_HALF)
	{
		g_iRounds = 0;
		g_iScores[CS_TEAM_T] = 0;
		g_iScores[CS_TEAM_CT] = 0;
		
		for(new iPlayer;iPlayer <= MaxClients;iPlayer++)
		{
			arrayset(g_iFrags[iPlayer],0,sizeof(g_iFrags[]));
		}
	}
	else if(STATE_HALFTIME <= g_iState <= STATE_OVERTIME)
	{
		for(new iPlayer;iPlayer <= MaxClients;iPlayer++)
		{
			if(is_user_connected(iPlayer))
			{
				g_iFrags[iPlayer][0] += get_user_frags(iPlayer);
				g_iFrags[iPlayer][1] += get_user_deaths(iPlayer);
			}
		}
	}
}

public HOOK_JoinTeamHandle(id)
{
	return PUG_CheckTeam(id,read_argv_int(1));
}

public HOOK_TeamSelectHandle(id,iKey)
{
	return PUG_CheckTeam(id,(iKey + 1));
}

PUG_CheckTeam(id,iSlot)
{
	if(iSlot == 5)
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_TEAM_AUTO");		
		return PLUGIN_HANDLED;
	}
	
	if(iSlot == 6)
	{
		if(!get_pcvar_num(g_pAllowSpec) && !access(id,ADMIN_LEVEL_A))
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_TEAM_SPEC");
			return PLUGIN_HANDLED;
		}
	}
	
	if((iSlot == 1) || (iSlot == 2))
	{
		if(PUG_GetPlayersTeam(CsTeams:iSlot) >= (get_pcvar_num(g_pPlayersMax) / 2))
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_TEAM_FULL");
			return PLUGIN_HANDLED;
		}
	}
	
	if(STATE_START <= g_iState <= STATE_END)
	{
		new CsTeams:iTeam = cs_get_user_team(id);
		
		if(iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT)
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_TEAM_NONE");
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public HOOK_JoinedClass(id)
{
	if(get_ent_data(id,"CBasePlayer","m_iMenu") == CS_Menu_ChooseAppearance && get_ent_data(id,"CBasePlayer","m_iJoiningState") == CS_STATE_PICKING_TEAM)
	{
		set_task(2.0,"PUG_JoinMessage",id);	
	}
}

public PUG_JoinMessage(id)
{
	if(is_user_connected(id))
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_BUILD_STRING1",PUG_MOD_PLUGIN,PUG_MOD_VERSION,PUG_MOD_AUTHOR);
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_BUILD_STRING2");
	}
}
