#if defined _PugStocks_included
	#endinput
#endif
#define _PugStocks_included

/**
 * Get Pug Mod configuration directory
 *
 * @note This is useful for get configs directory based on Amx Mod X.
 *
 * @param szPatch	Buffer to copy patch to
 * @param iLen		Maximum buffer size
 *
 * @noreturn
 */
stock PUG_GetFilePath(const szFile[],szPath[],iLen)
{
	get_localinfo("amxx_configsdir",szPath,iLen);
	formatex(szPath,iLen,"%s/pug/%s",szPath,szFile);
}

/**
 * Register new client command
 *
 * @note This is useful for register command using translation system,
 * 	 If command have admin flags, will be registred as !%s, if not as .%s
 *
 * @param szCommand		Command to register
 * @param szFunction		Function callback
 * @param iFlags		Admin flags needed
 * @param szInfo		Information string
 * @param bTranslate		Translate information string
 *
 * @noreturn
 */
stock PUG_RegCommand(const szCommand[],const szFunction[],iFlags = 0,const szInfo[] = "",bool:bTranslate = true)
{
	new szBuffer[16];
	formatex(szBuffer,charsmax(szBuffer),(iFlags == ADMIN_ALL) ? ".%s" : "!%s",szCommand);
	
	if(szInfo[0] && bTranslate)
	{
		new szKey[64];
		format(szKey,charsmax(szKey),"%L",LANG_SERVER,szInfo);

		register_clcmd(szBuffer,szFunction,iFlags,szKey);
	}
	else
	{
		register_clcmd(szBuffer,szFunction,iFlags,szInfo);
	}
}

/**
 * Execute a PUG function with client as parameter and display a result in chat
 *
 * @note This is only for execute functions that return an value
 *
 * @param id			Caller index (Usually an admin)
 * @param Command		String of the command
 * @param Lang			Lang string in language system
 * @param Target		Target client index
 * @param Check			The function to call or it's result
 *
 * @noreturn
 */
stock PUG_CommandClient(id,szCommand[],szLang[],iClient,iCheck)
{
	if(iCheck)
	{
		new szName[MAX_NAME_LENGTH];
		get_user_name(iClient,szName,charsmax(szName));
	
		client_print_color(0,iClient,"%s %L",PUG_MOD_HEADER,LANG_SERVER,szLang,szName);
	}
	
	client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,iCheck ? "PUG_CMD_OK" : "PUG_CMD_FAIL",szCommand);
}

/**
 * Execute a PUG function and display a result in chat
 *
 * @note This is only for execute functions that return an value
 *
 * @param id			Caller index (Usually an admin)
 * @param Command		String of the command
 * @param Lang			Lang string in language system
 * @param Check			The function to call or it's result
 *
 * @noreturn
 */
stock PUG_ExecuteCommand(id,szCommand[],szLang[],bCheck)
{
	if(bCheck)
	{
		new szName[MAX_NAME_LENGTH];
		get_user_name(id,szName,charsmax(szName));
		
		client_print_color(0,id,"%s %L",PUG_MOD_HEADER,LANG_SERVER,szLang,szName,szCommand);
	}
	
	client_print_color(id,id,"%s %L",PUG_MOD_HEADER,LANG_PLAYER,bCheck ? "PUG_CMD_OK" : "PUG_CMD_FAIL",szCommand);
}

/**
 * Get Pug Map List
 *
 * @note This is used to build maps menu for votes
 *
 * @param Data			2D data array returned from function
 * @param Len			Size of Data Array
 *
 * @return              	Maps Loaded count
 */
stock PUG_GetMapList(szData[][],iLen,StayHere)
{
	new szPath[PLATFORM_MAX_PATH];
	PUG_GetFilePath("maps.rc",szPath,charsmax(szPath));

	new iCount;
	if(StayHere)
		copy(szData[iCount++],iLen,fmt("%L",LANG_SERVER,"PUG_VOTEMAP_STAYHERE"));
	
	if(file_exists(szPath))
	{
		new iFile = fopen(szPath,"rb");
		new szLine[MAX_NAME_LENGTH];
	
		while(!feof(iFile) && (iCount < iLen))
		{
			fgets(iFile,szLine,charsmax(szLine));
			trim(szLine);
			
			if(is_map_valid(szLine) && !equali(MapName,szLine))
			{
				copy(szData[iCount++],iLen,szLine);
			}
		}
		
		fclose(iFile);
		return iCount;
	}
	
	return 0;
}

/**
 * Build the help file (.html) for commands at config dir
 *
 * @note This is used to automatically build a file with registred commands
 *
 * @param Level			Admin level constant (See amxconst for flags)
 * @param Name			Name of the file to check or build
 * @param Tag			First character to check command (Usually . for PUG)
 *
 * @noreturn
 */
stock PUG_BuildHelpFile(iLevel)
{
	new szPath[64];	
	PUG_GetFilePath((iLevel == ADMIN_ALL) ? "help.htm" : "admin.htm",szPath,charsmax(szPath));
	
	if(!file_exists(szPath))
	{
		new iCommands = get_concmdsnum(iLevel);
		
		if(iCommands)
		{
			new iFile = fopen(szPath,"wt");
			fputs(iFile,"<style type='text/css'>body{background:#000;margin:2px;color:#FFB000;font-family:Tahoma}</style><table width='100%%'>");
			
			new szString[MAX_NAME_LENGTH],iFlag,szInfo[128];
			
			for(new i;i < iCommands;i++)
			{
				get_concmd(i,szString,charsmax(szString),iFlag,szInfo,charsmax(szInfo),iLevel);
				
				if((szString[0] == ((iLevel == ADMIN_ALL) ? '.' : '!')) && szInfo[0])
				{
					replace_all(szInfo,sizeof(szInfo),"<","&#60;");
					replace_all(szInfo,sizeof(szInfo),">","&#62;");
					
					fprintf(iFile,"<tr><td>%s</td><td>%s</td></tr>",szString,szInfo);
				}
			}
			
			fclose(iFile);
		}
	}
}

/**
 * Build the pugmod.rc file (.rc) for cvars in PUG config dir
 *
 * @note This is used to automatically build a file with registred cvars
 *
 * @param Name			Name of the file to check or build
 * @param Help			Build file as html to help admins
 * @noreturn
 */
stock PUG_BuildCvarsFile(szFile[],bool:bHelp)
{
	new szPath[64];	
	PUG_GetFilePath(szFile,szPath,charsmax(szPath));
	
	if(!file_exists(szPath))
	{
		new iCvarsNum = get_plugins_cvarsnum();
		
		if(iCvarsNum)
		{
			new iFile = fopen(szPath,"wt");
			
			if(bHelp)
			{
				fputs(iFile,"<style type='text/css'>body{background:#000;margin:2px;color:#FFB000;font-family:Tahoma}</style><table width='100%%'>");
			}
			
			new szName[MAX_NAME_LENGTH],iFlag,iPlugin,iHandle,szDesc[128],szValue[MAX_NAME_LENGTH];
			
			for(new i;i < iCvarsNum;i++)
			{
				if(get_plugins_cvar(i,szName,charsmax(szName),iFlag,iPlugin,iHandle,szDesc,charsmax(szDesc)))
				{
					if((szName[0] == 'p') && (szName[1] == 'u') && (szName[2] == 'g'))
					{
						if(bHelp)
						{
							replace_all(szDesc,sizeof(szDesc),"<","&#60;");
							replace_all(szDesc,sizeof(szDesc),">","&#62;");
							
							fprintf(iFile,"<tr><td>%s</td><td>%s</td></tr>",szName,szDesc);
						}
						else
						{
							get_pcvar_string(iHandle,szValue,charsmax(szValue));
							
							fprintf(iFile,"%s		^"%s^"			// %s^n",szName,szValue,szDesc);
						}
					}
				}
			}
			
			fclose(iFile);
		}
	}
}
