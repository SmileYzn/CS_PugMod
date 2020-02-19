#include <amxmodx>
#include <csx>

#include <PugCore>
#include <PugStocks>
#include <PugCS>

new bool:g_bLive;

public plugin_init()
{
	register_plugin("Pug Mod (Stats)",PUG_MOD_VERSION,PUG_MOD_AUTHOR);

	register_dictionary("PugStats.txt");
	
	PUG_RegCommand("hp","PUG_HP",ADMIN_ALL,"PUG_DESC_HP");
	PUG_RegCommand("dmg","PUG_DamageDone",ADMIN_ALL,"PUG_DESC_DMG");
	PUG_RegCommand("rdmg","PUG_DamageReceived",ADMIN_ALL,"PUG_DESC_RDMG");
	PUG_RegCommand("sum","PUG_DamageSummary",ADMIN_ALL,"PUG_DESC_SUM");
}

public PUG_Event(iState)
{
	g_bLive = (iState == STATE_FIRST_HALF || iState == STATE_SECOND_HALF || iState == STATE_OVERTIME);
}

public PUG_HP(id)
{
	if(g_bLive && PUG_PLAYER_IN_TEAM(id) && (!is_user_alive(id) || get_gamerules_int("CHalfLifeMultiplay","m_bRoundTerminating")))
	{
		new iPlayers[MAX_PLAYERS],iNum;
		get_players(iPlayers,iNum,"aeh",(get_user_team(id) == 1) ? "CT" : "TERRORIST");
		
		if(iNum)
		{
			new szName[MAX_NAME_LENGTH],iPlayer;
			
			for(new i;i < iNum;i++)
			{
				iPlayer = iPlayers[i];
			
				get_user_name(iPlayer,szName,charsmax(szName));
				
				client_print_color(id,iPlayer,"%s %L",PUG_MOD_HEADER,id,"PUG_HP_CMD",szName,get_user_health(iPlayer),get_user_armor(iPlayer));
			}
		}
		else
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_HP_NONE");
		}
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	}
	
	return PLUGIN_HANDLED;
}

public PUG_DamageDone(id)
{
	if(g_bLive && PUG_PLAYER_IN_TEAM(id) && (!is_user_alive(id) || get_gamerules_int("CHalfLifeMultiplay","m_bRoundTerminating")))
	{
		new szName[MAX_NAME_LENGTH];
		new szStats[STATSX_MAX_STATS],szBody[MAX_BODYHITS];
		
		new bool:bStats;
		
		new iPlayers[MAX_PLAYERS],iNum,iPlayer;
		get_players(iPlayers,iNum,"e",(get_user_team(id) == 1) ? "CT" : "TERRORIST");
		
		for(new i;i < iNum;i++)
		{
			iPlayer = iPlayers[i];
			
			arrayset(szStats,0,sizeof(szStats));
			
			if(get_user_vstats(id,iPlayer,szStats,szBody))
			{
				bStats = true;
				get_user_name(iPlayer,szName,charsmax(szName));

				client_print_color(id,iPlayer,"%s %L",PUG_MOD_HEADER,id,"PUG_DMG",szName,szStats[STATSX_HITS],szStats[STATSX_DAMAGE]);
			}
		}
		
		if(!bStats)
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_NODMG");
		}
		
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	}
	
	return PLUGIN_HANDLED;
}

public PUG_DamageReceived(id)
{
	if(g_bLive && PUG_PLAYER_IN_TEAM(id) && (!is_user_alive(id) || get_gamerules_int("CHalfLifeMultiplay","m_bRoundTerminating")))
	{
		new szName[MAX_NAME_LENGTH];
		new szStats[STATSX_MAX_STATS],szBody[MAX_BODYHITS];
		
		new bool:bStats;
		
		new iPlayers[MAX_PLAYERS],iNum,iPlayer;
		get_players(iPlayers,iNum,"e",(get_user_team(id) == 1) ? "CT" : "TERRORIST");
		
		for(new i;i < iNum;i++)
		{
			iPlayer = iPlayers[i];
			
			arrayset(szStats,0,sizeof(szStats));

			if(get_user_astats(id,iPlayer,szStats,szBody))
			{
				bStats = true;
				get_user_name(iPlayer,szName,charsmax(szName));
				
				client_print_color(id,iPlayer,"%s %L",PUG_MOD_HEADER,id,"PUG_RDMG",szName,szStats[STATSX_HITS],szStats[STATSX_DAMAGE]);
			}
		}
		
		if(!bStats)
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_NORDMG");
		}		
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	}
	
	return PLUGIN_HANDLED;
}

public PUG_DamageSummary(id)
{
	if(g_bLive && PUG_PLAYER_IN_TEAM(id) && (!is_user_alive(id) || get_gamerules_int("CHalfLifeMultiplay","m_bRoundTerminating")))
	{
		new szName[MAX_NAME_LENGTH];
		new szStats[2][STATSX_MAX_STATS],szBody[2][MAX_BODYHITS];
		
		new bool:bStats;
		
		new iPlayers[MAX_PLAYERS],iNum,iPlayer;
		get_players(iPlayers,iNum,"e",(get_user_team(id) == 1) ? "CT" : "TERRORIST");
		
		for(new i;i < iNum;i++)
		{
			iPlayer = iPlayers[i];
			
			arrayset(szStats[0],0,sizeof(szStats[]));
			arrayset(szStats[1],0,sizeof(szStats[]));
			
			if(get_user_vstats(id,iPlayer,szStats[0],szBody[0]) || get_user_astats(id,iPlayer,szStats[1],szBody[1]))
			{
				bStats = true;
				get_user_name(iPlayer,szName,charsmax(szName));
				
				client_print_color(id,iPlayer,"%s %L",PUG_MOD_HEADER,id,"PUG_SUM",szStats[0][STATSX_DAMAGE],szStats[0][STATSX_HITS],szStats[1][STATSX_DAMAGE],szStats[1][STATSX_HITS],szName,is_user_alive(iPlayer) ? get_user_health(iPlayer) : 0);
			}
		}
		
		if(!bStats)
		{
			client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_NOSUM");
		}
	}
	else
	{
		client_print_color(id,id,"%s %L",PUG_MOD_HEADER,id,"PUG_CMD_ERROR");
	}
	
	return PLUGIN_HANDLED;
}
