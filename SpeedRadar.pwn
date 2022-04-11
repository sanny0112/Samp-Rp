#include <a_samp>
#include <dc_cmd>
#define SSCANF_NO_NICE_FEATURES
#include <sscanf2>
#include <streamer>

// updateRadarAuthorName(oldName[MAX_PLAYER_NAME+1], nextName[MAX_PLAYER_NAME+1])
//                              - Вызвать при смене игроком ника. Обновляет его штрафы и меняет авторство в установленных радарах
// ResetAllSpeedRadar() 		- Полный сброс радаров (включая маппинг) и удаление всех штрафов
// SpeedRadarTicketsPayDay()    - Вызвать при PayDay. Переносит штрафы из "за последний час" в "за текущие сутки"

// Присутствуют 2 бага, на исправление которых не хватило времени:
// 1 - поворот маппинга,
// 2 - отсутствие страниц в диалогах с нарушителями и штрафами => возможно переполнение.
// Остальные элементы ТЗ были выполнены в полном объёме.

// ===========[ Radar FORWARDS ]===========
forward RadarInstall(playerid);
forward CameraPlace(playerid);
// ========================================

new Text:SpeedShow[MAX_PLAYERS];
new Text:KMShow[MAX_PLAYERS];
forward UpdateSpeedometr();

enum pInfo {
	pMember,
	pRank,
	pLeader,
	pAdmin,
	pMoney,
	pOnDuty
};
new PlayerInfo[MAX_PLAYERS][pInfo];
new NULL_PlayerInfo[pInfo];

// ===========[ Radar VARS ]===========
enum srInfo {
	Float:srX,
	Float:srY,
	Float:srZ,
	Float:srAngle,
	bool:srIsInstalled,
	bool:srIsInstalled2,
	srAuthorName[MAX_PLAYER_NAME+1],
	srAuthorRank[32],
	srLocation[64],
	Text3D:srText3DId,
	srObjectId[10],
	srSpeedLimit,
	srNoticeZone,
	srTicketZone
};
new SpeedRadarInfo[15][srInfo];
new NULL_SpeedRadarInfo[srInfo];
new CameraInstallTimer[MAX_PLAYERS];
new CameraInstallId[MAX_PLAYERS];
new Float:CameraInstallStartPoint[MAX_PLAYERS][3];
enum srTickets {
	srtPlayerName[MAX_PLAYER_NAME+1],
	srtCar,
	srtSpeedLimit,
	srtPlayerSpeed,
	srtPolice,
	bool:srtAfterPayDay
};
new srTicketsIndex = 0;
new SpeedRadarTickets[MAX_PLAYERS*4][srTickets];
new NULL_SpeedRadarTickets[srTickets];
// ====================================

static const FractionSkin[3] = {295, 283, 115};
new Float:SpawnInfo[3][4] = {
{2202.1167,2478.0464,11.8203,180.0}, // Гражданский
{2290.6106,2450.9822,10.8203,90.0}, // LVPD
{2125.8381,2474.2617,11.8203,90.0} // Бандит
};

new const Float:Cites[9][4] = {
// [minx], [miny], [maxx], [maxy]
{-2165.0, 1563.0, -650.0, 3000.0},	// Las Venturas
{-650.0, 465.0, 3000.0, 3000.0},	// Las Venturas
{-1167.0, 626.0, -650.0, 1563.0},	// Las Venturas
{-3000.0, -3000.0, -2165.0, 3000.0},// San Fierro
{-2165.0, -3000.0, -1167.0, 1563.0},// San Fierro
{-1167.0, -3000.0, -650.0, 626.0},	// San Fierro
{-650.0, -3000.0, 86.0, -1681.0},	// San Fierro
{-650.0, -1681.0, 3000.0, 465.0},	// Los Santos
{86.0, -3000.0, 3000.0, -1681.0}	// Los Santos
};

new VehicleNames[212][] = {
	"Landstalker","Bravura","Buffalo","Linerunner","Perrenial","Sentinel","Dumper","Firetruck","Trashmaster","Stretch","Manana","Infernus",
	"Voodoo","Pony","Mule","Cheetah","Ambulance","Leviathan","Moonbeam","Esperanto","Taxi","Washington","Bobcat","Mr.Whoopee","BF Injection",
	"Hunter","Premier","Enforcer","Securicar","Banshee","Predator","Bus","Rhino","Barracks","Hotknife","Trailer","Previon","Coach","Cabbie",
	"Stallion","Rumpo","RC Bandit","Romero","Packer","Monster","Admiral","Squalo","Seasparrow","Pizzaboy","Tram","Trailer","Turismo","Speeder",
	"Reefer","Tropic","Flatbed","Yankee","Caddy","Solair","Berkley's RC Van","Skimmer","PCJ-600","Faggio","Freeway","RC Barron","RC Raider",
	"Glendale","Oceanic","Sanchez","Sparrow","Patriot","Quad","Coastguard","Dinghy","Hermes","Sabre","Rustler","Zr-350","Walton","Regina",
	"Comet","BMX","Burrito","Camper","Marquis","Baggage","Dozer","Maverick","News Chopper","Rancher","FBI Rancher","Virgo","Greenwood",
	"Jetmax","Hotring","Sandking","Blista Compact","Police Maverick","Boxville","Benson","Mesa","RC Goblin","Hotring A","Hotring B",
	"Bloodring Banger","Rancher","Super GT","Elegant","Journey","Bike","Mountain Bike","Beagle","Cropdust","Stunt","Tanker","RoadTrain",
	"Nebula","Majestic","Buccaneer","Shamal","Hydra","FCR-900","NRG-500","HPV1000","Cement Truck","Tow Truck","Fortune","Cadrona","FBI Truck",
	"Willard","Forklift","Tractor","Combine","Feltzer","Remington","Slamvan","Blade","Freight","Streak","Vortex","Vincent","Bullet","Clover",
	"Sadler","Firetruck","Hustler","Intruder","Primo","Cargobob","Tampa","Sunrise","Merit","Utility","Nevada","Yosemite","Windsor","Monster A",
	"Monster B","Uranus","Jester","Sultan","Stratum","Elegy","Raindance","RC Tiger","Flash","Tahoma","Savanna","Bandito","Freight","Trailer",
	"Kart","Mower","Duneride","Sweeper","Broadway","Tornado","AT-400","DFT-30","Huntley","Stafford","BF-400","Newsvan","Tug","Trailer A","Emperor",
	"Wayfarer","Euros","Hotdog","Club","Trailer B","Trailer C","Andromada","Dodo","RC Cam","Launch","Police Car","Police Car",
	"Police Car","Police Ranger","Picador","S.W.A.T.","Alpha","Phoenix","Glendale","Sadler","L Trailer A","L Trailer B",
	"Stair Trailer","Boxville","Farm Plow","U Trailer"
};

main()
{
	print("\n----------------------------------");
	print(" SpeedRadar Gamemode activated");
	print("----------------------------------\n");
}

public OnGameModeInit()
{
	SetGameModeText("SpeedRadar");
	AddStaticVehicle(598,2273.5933,2459.8660,10.5669,181.6427,0,1); // Полицейский автомобиль
	AddStaticVehicle(522,2202.1167,2478.0464,10.8203,180.0,1,1); // Гражданский NRG
	AddStaticVehicle(535,2125.8381,2474.2617,10.8203,90.0,15,15); // Бандитский автомобиль
	SetTimer("UpdateSpeedometr", 120, true); // Спидометр
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	new PlayerFrac = getPlayerFraction(playerid);
	SetSpawnInfo(playerid, 0, FractionSkin[PlayerFrac],SpawnInfo[PlayerFrac][0],SpawnInfo[PlayerFrac][1],SpawnInfo[PlayerFrac][2],SpawnInfo[PlayerFrac][3], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

public OnPlayerConnect(playerid)
{
    SendClientMessage(playerid, -1, " Добро пожаловать! Основные команды:");
    SendClientMessage(playerid, -1, " - /sradar [...] - Радар");
    SendClientMessage(playerid, -1, " - /leader [id frac] - Стать лидером фракции");
    SendClientMessage(playerid, -1, " - /frac - Вступить во фракцию");
    SendClientMessage(playerid, -1, " - /rank [rank] - Выдать себе ранг");
    SendClientMessage(playerid, -1, " - /r или /f - Рация");
    SendClientMessage(playerid, -1, " - /reset - Общий сброс радара");
    SendClientMessage(playerid, -1, " - /payday - Вызвать PayDay");
    
    PlayerInfo[playerid][pLeader] = 0;
    PlayerInfo[playerid][pMember] = random(3);
    PlayerInfo[playerid][pRank] = 5;
    PlayerInfo[playerid][pOnDuty] = true;
    // ===========[ Radar ]===========
    CameraInstallTimer[playerid] = 0;
    // ===============================
    PlayerInfo[playerid][pMoney] = 50000;
    GivePlayerMoney(playerid,PlayerInfo[playerid][pMoney]);
    // Спидометр
    SpeedShow[playerid] = TextDrawCreate(374.000000, 408.000000, "_");
    TextDrawBackgroundColor(SpeedShow[playerid], 255);
    TextDrawAlignment(SpeedShow[playerid], 2);
    TextDrawLetterSize(SpeedShow[playerid],0.500000, 1.500000);
    TextDrawFont(SpeedShow[playerid],0);
    TextDrawColor(SpeedShow[playerid], 761773823);
    TextDrawSetOutline(SpeedShow[playerid],1);
    TextDrawSetProportional(SpeedShow[playerid],1);
	TextDrawSetShadow(SpeedShow[playerid],1);
    TextDrawHideForPlayer(playerid, SpeedShow[playerid]);
    
    KMShow[playerid] = TextDrawCreate(393.000000, 410.000000, "_");
    TextDrawBackgroundColor(KMShow[playerid], 255);
    TextDrawLetterSize(KMShow[playerid],0.379999, 0.899999);
    TextDrawFont(KMShow[playerid], 2);
    TextDrawColor(KMShow[playerid], 724790015);
    TextDrawSetOutline(KMShow[playerid], 1);
    TextDrawSetProportional(KMShow[playerid],1);
	TextDrawSetShadow(KMShow[playerid],1);
    TextDrawHideForPlayer(playerid, KMShow[playerid]);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    PlayerInfo[playerid] = NULL_PlayerInfo;
    // ===========[ Radar ]===========
    if (CameraInstallTimer[playerid] != 0)
	{
  		if(SpeedRadarInfo[CameraInstallId[playerid]][srIsInstalled2])
		{
			new string[128];
		    format(string,sizeof(string)," [Speed Cam] %s удалил камеру в районе %s",GetName(playerid),SpeedRadarInfo[CameraInstallId[playerid]][srLocation]);
			SendRadioMessage(getPlayerFraction(playerid), string);
		}
	    KillTimer(CameraInstallTimer[playerid]);
	    DisablePlayerCheckpoint(CameraInstallTimer[playerid]);
		CameraInstallTimer[playerid] = 0;
		SpeedRadarInfo[CameraInstallId[playerid]] = NULL_SpeedRadarInfo;
	}
	// ==============================
	return 1;
}

public OnPlayerSpawn(playerid)
{
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(newstate == PLAYER_STATE_DRIVER)
	{
	    TextDrawShowForPlayer(playerid,SpeedShow[playerid]);
	    TextDrawShowForPlayer(playerid,KMShow[playerid]);
	}
    else if(newstate == PLAYER_STATE_ONFOOT)
    {
        TextDrawHideForPlayer(playerid,SpeedShow[playerid]);
        TextDrawHideForPlayer(playerid,KMShow[playerid]);
    }
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    // ===========[ Radar ]===========
    if (newkeys == 2 && CameraInstallTimer[playerid] != 0)
	{
	    KillTimer(CameraInstallTimer[playerid]);
		CameraInstallTimer[playerid] = 0;
		ApplyAnimation(playerid, "BOMBER", "BOM_PLANT", 4.1, false, false, false, false, 0, false);
		DisablePlayerCheckpoint(CameraInstallTimer[playerid]);
		SetTimerEx("CameraPlace", 2500, false, "i", playerid);
	}
	// ===============================
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
	    // ===========[ Radar ]===========
		case 1: // Выбор фракции
		{
			if(response == 0)
			    return 1;
		 	PlayerInfo[playerid][pMember] = listitem;
		 	PlayerInfo[playerid][pRank] = 1;
		 	PlayerInfo[playerid][pLeader] = 0;
		 	if(IsPlayerInAnyVehicle(playerid)) {
		 		new Float:player_pos[3];
				GetPlayerPos(playerid,player_pos[0],player_pos[1],player_pos[2]);
				SetPlayerPos(playerid,player_pos[0],player_pos[1],player_pos[2]+0.1);
		 	}
		 	ForceClassSelection(playerid);
		 	TogglePlayerSpectating(playerid, true);
    		TogglePlayerSpectating(playerid, false);
    		new string[128];
    		if (PlayerInfo[playerid][pMember] != 0)
    			format(string,sizeof(string)," Вы приглашены в %s",GetFractionName(PlayerInfo[playerid][pMember]));
			else
			    format(string,sizeof(string)," Вы уволены из фракции");
    		SendClientMessage(playerid, 0x6ab1ff00, string);
		}
		case 2: // /sradar info
		{
            if(response == 0)
			    return 1;
			if(listitem == 0 || listitem == 1) // [0] Нарушители за последний час && [1] Нарушители за текущие сутки
			{
				static const fmt_str[] = "%s[%i] %s[%i]\t%s\t%i (+%i)\n";
				new dialog_header[46] = "Имя [ID]\tАвтомобиль\tСкорость\n",
		  		dialog_title[32],
			    string[sizeof(dialog_header) + (sizeof(fmt_str) + (-2) + (-2 + 4) + (-2 + MAX_PLAYER_NAME) + (-2 + 19) + (-2 + 32) + (-2 + 3) + (-2 + 2)) * 32],
			    TicketsCount = 0,
			    TicketPlayerId,
				PlayerFrac = getPlayerFraction(playerid), // Фракция игрока
			    selectPDSlots = 0;
			    string = dialog_header;
				if(PlayerFrac == 3)      // id LSPD
				    selectPDSlots = 1;
				else if(PlayerFrac == 4) // id SFPD
				    selectPDSlots = 2;
				else if(PlayerFrac == 1) // id LVPD
				    selectPDSlots = 3;
			    for(new i=0; i < srTicketsIndex; i++)
				{
					if(SpeedRadarTickets[i][srtPolice] == selectPDSlots  && (!SpeedRadarTickets[i][srtAfterPayDay] && listitem == 0 || SpeedRadarTickets[i][srtAfterPayDay] && listitem == 1)) {
						TicketPlayerId = GetPlayerID(SpeedRadarTickets[i][srtPlayerName]);
						if(TicketPlayerId > -1)
					    	format(string, sizeof(string), fmt_str, string, ++TicketsCount, SpeedRadarTickets[i][srtPlayerName], TicketPlayerId, VehicleNames[SpeedRadarTickets[i][srtCar]-400], SpeedRadarTickets[i][srtPlayerSpeed], SpeedRadarTickets[i][srtPlayerSpeed]-SpeedRadarTickets[i][srtSpeedLimit]);
						else
						    format(string, sizeof(string), "%s[%i] %s[{CC0000}off{FFFFFF}]\t%s\t%i (%i)\n", string, ++TicketsCount, SpeedRadarTickets[i][srtPlayerName], VehicleNames[SpeedRadarTickets[i][srtCar]-400], SpeedRadarTickets[i][srtPlayerSpeed], SpeedRadarTickets[i][srtPlayerSpeed]-SpeedRadarTickets[i][srtSpeedLimit]);
					}
				}
				if(listitem == 0)
				    dialog_title = "Нарушители за последний час";
				else
				    dialog_title = "Нарушители за текущие сутки";
				if(TicketsCount > 0)
				    ShowPlayerDialog(playerid, 3, DIALOG_STYLE_TABLIST_HEADERS, dialog_title, string, "Ок", "Назад");
			    else
			        SendClientMessage(playerid, 0xAFAFAF00, " Нарушителей не обнаружено");
				return 1;
			}
			else if(listitem == 2) // [2] Активные камеры
			{
				
				static const fmt_str[] = "%s[%i] %s\t%i\t%s\n";
				new dialog_header[39] = "Установил\tЛимит\tНазвание местности\n",
			    string[sizeof(dialog_header) + (sizeof(fmt_str) + (-2) + (-2 + 1) + (-2 + MAX_PLAYER_NAME) + (-2 + 3) + (-2 + 64)) * 5],
				PlayerFrac = getPlayerFraction(playerid), // Фракция игрока
			    selectPDSlots = 0,
				CameraNumber=0;
				if(PlayerFrac == 3)      // id LSPD
				    selectPDSlots = 1;
				else if(PlayerFrac == 4) // id SFPD
				    selectPDSlots = 2;
				else if(PlayerFrac == 1) // id LVPD
				    selectPDSlots = 3;
				string = dialog_header;
			    for(new i=(selectPDSlots-1)*5; i < selectPDSlots*5; i++)
				{
					if(SpeedRadarInfo[i][srIsInstalled2] == true) {
					    format(string, sizeof(string), fmt_str, string, ++CameraNumber, SpeedRadarInfo[i][srAuthorName], SpeedRadarInfo[i][srSpeedLimit], SpeedRadarInfo[i][srLocation]);
					}
				}
				if(CameraNumber > 0)
				    ShowPlayerDialog(playerid, 3, DIALOG_STYLE_TABLIST_HEADERS, "Активные камеры", string, "Ок", "Назад");
			    else
			        SendClientMessage(playerid, 0xAFAFAF00, " Ни одной камеры не установлено");
				return 1;
			}
			
		}
		case 3: // back to dialog 2
		{
			if(response == 1)
			    return 1;
            ShowPlayerDialog(playerid, 2, DIALOG_STYLE_LIST, "Скоростной радар", "[0] Нарушители за последний час\n[1] Нарушители за текущие сутки\n[2] Активные камеры", "Выбрать", "Закрыть");
		}
		case 4: // Speed Tickets
		{
		  	if(response == 0)
			    return 1;
		    new TicketsCount = 0,
		    TicketAmount,
			string[128];
		    for(new i=0; i < srTicketsIndex; i++)
			{
			    if(strcmp(SpeedRadarTickets[i][srtPlayerName],GetName(playerid)) == 0)
			    {
			        TicketsCount++;
			        if(TicketsCount-1 == listitem)
			        {
			            TicketAmount = 2000 * ((SpeedRadarTickets[i][srtPlayerSpeed]-SpeedRadarTickets[i][srtSpeedLimit]) / 10);
			            if(!GiveMoney(playerid, (-TicketAmount))) // Списание денег
			            {
		  					SendClientMessage(playerid, 0xAFAFAF00, " На вашем счету недостаточно средств");
							return 0;
			            }
			            SpeedRadarTickets[i] = NULL_SpeedRadarTickets;
						for(new j=i; j < srTicketsIndex; j++)
						{
						    SpeedRadarTickets[j] = SpeedRadarTickets[j+1];
						}
	  					srTicketsIndex--;
	  					format(string, sizeof(string), " С вашего счёта было списано %i вирт", TicketAmount);
	  					SendClientMessage(playerid, -1, string);
						break;
			        }
			    }
			}
			SpeedRadarTicket(playerid);
		    return 1;
		}
		// ==============================
	}
	return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}

// КОМАНДЫ
CMD:payday(playerid, parms[])
{
    SendClientMessage(playerid, -1, " PayDay");
    SpeedRadarTicketsPayDay();
	return 1;
}
CMD:reset(playerid, parms[])
{
    SendClientMessage(playerid, -1, " Сброс выполнен");
    ResetAllSpeedRadar();
	return 1;
}
CMD:r(playerid, params[])
{
	new string[128];
	if (getPlayerFraction(playerid) == 0) {
		SendClientMessage(playerid, 0xAFAFAF00, " Вам недоступен этот чат");
		return 0;
	}
	if(sscanf(params, "s[128]", string))
		return SendClientMessage(playerid, -1, " Введите: /r [текст]");
    format(string,sizeof(string)," [R] %s %s: %s",(PlayerInfo[playerid][pLeader] == 0) ? GetRankName(PlayerInfo[playerid][pMember], PlayerInfo[playerid][pRank]) : GetLeaderName(PlayerInfo[playerid][pLeader]),GetName(playerid),string);
    SendRadioMessage(getPlayerFraction(playerid), string);
    return 1;
}
ALT:r:f;
CMD:rank(playerid, params[])
{
    new rank;
    new string[128];
	new UserFraction = PlayerInfo[playerid][pMember];
	if (UserFraction == 0) {
		SendClientMessage(playerid, 0xAFAFAF00, " Вы не состоите во фракции");
		return 0;
	}
	if(sscanf(params, "i", rank) || rank <=0)
		return SendClientMessage(playerid, -1, " Введите: /rank [ранг]");
	PlayerInfo[playerid][pRank] = rank;
    format(string,sizeof(string)," Вы повышены/понижены до %i ранга",rank);
	SendClientMessage(playerid, 0x6ab1ff00, string);
	return 1;
}
CMD:leader(playerid, params[])
{
    new frac;
    new string[128];
	if(sscanf(params, "i", frac) || frac <0)
		return SendClientMessage(playerid, -1, " Введите: /leader [id фракции]");
	PlayerInfo[playerid][pMember] = 0;
	PlayerInfo[playerid][pRank] = 0;
	PlayerInfo[playerid][pLeader] = frac;
	if(IsPlayerInAnyVehicle(playerid)) {
 		new Float:player_pos[3];
		GetPlayerPos(playerid,player_pos[0],player_pos[1],player_pos[2]);
		SetPlayerPos(playerid,player_pos[0],player_pos[1],player_pos[2]+0.1);
 	}
 	ForceClassSelection(playerid);
 	TogglePlayerSpectating(playerid, true);
	TogglePlayerSpectating(playerid, false);
    format(string,sizeof(string)," Вы назначены на пост лидера %s",GetFractionName(frac));
	SendClientMessage(playerid, 0x6ab1ff00, string);
	return 1;
}
CMD:frac(playerid, params[])
{
	new frName[128], string[128];
	frName = GetFractionName(getPlayerFraction(playerid));
	if (getPlayerFraction(playerid) != 0)
		format(string,sizeof(string)," Вы состоите во фракции %s",frName);
	else
	    format(string,sizeof(string)," Вы не состоите во фракции");
	SendClientMessage(playerid, -1, string);

	ShowPlayerDialog(playerid, 1, DIALOG_STYLE_LIST, "Выбор фракции", "[0] Гражданский\n[2] LVPD\n[3] Бандит", "Выбрать", "Закрыть");


	return 1;
}
//=================================[ SPEED RADAR ]=================================
CMD:sradar(playerid, params[])
{
    new key[16], LocationName[64],slimitValue,
 	PlayerFrac = getPlayerFraction(playerid), // Фракция игрока
 	AdminLvl = PlayerInfo[playerid][pAdmin], // Определить уровень администратора
    selectPDSlots = 0;
	if(PlayerFrac == 3)      // id LSPD
	    selectPDSlots = 1;
	else if(PlayerFrac == 4) // id SFPD
	    selectPDSlots = 2;
	else if(PlayerFrac == 1) // id LVPD
	    selectPDSlots = 3;
    if(sscanf(params, "s[16] ", key) || strcmp(key,"set",true) != 0 && strcmp(key,"edit",true) != 0 && strcmp(key,"del",true) != 0 && strcmp(key,"info",true) != 0 && strcmp(key,"ticket",true) != 0) {
        if(selectPDSlots != 0 && PlayerInfo[playerid][pOnDuty])
			return SendClientMessage(playerid, -1, " Введите: /sradar [ключ] | Ключи: set, edit, del, info");
		else if(AdminLvl >= 3)
		    return SendClientMessage(playerid, -1, " Введите: /sradar del");
		else
		    return SendClientMessage(playerid, -1, " Введите: /sradar ticket");
 	}
	if(strcmp(key,"set",true) == 0)
	{
	    if(selectPDSlots == 0)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Вам недоступна эта функция");
	    if(sscanf(params, "{s[16]} i s[128]", slimitValue, LocationName))
	    	return SendClientMessage(playerid, -1, " Введите: /sradar set [slimit] [название местности]");
		if(slimitValue<60 || slimitValue>100)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Ограничение скорости должно быть от 60 до 100 км/ч");
        if(IsPlayerInAnyVehicle(playerid))
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Недоступно в транспорте");
		if(PlayerInfo[playerid][pRank] < 5 && PlayerInfo[playerid][pLeader] == 0)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Функция доступна с 5 ранга");
		if(getPlayerCity(playerid) != selectPDSlots-1)
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Недоступно вне своей юрисдикции");
		if(getNearestRadar(playerid, 50) != -1)
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Рядом уже установлена камера");
	    if(GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Недоступно в помещении");
        new freeRadarSlot = 15;
        for(new i=(selectPDSlots-1)*5; i < selectPDSlots*5; i++)
		{
			if(SpeedRadarInfo[i][srIsInstalled] != true) {
			    freeRadarSlot = i;
			    break;
			 }
		}
		if(freeRadarSlot == 15)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Все доступные камеры уже установлены");
        SpeedRadarInfo[freeRadarSlot][srIsInstalled] = true;
	 	SpeedRadarInfo[freeRadarSlot][srAuthorName] = GetName(playerid);
	 	SpeedRadarInfo[freeRadarSlot][srAuthorRank] = (PlayerInfo[playerid][pLeader] == 0) ? GetRankName(PlayerInfo[playerid][pMember], PlayerInfo[playerid][pRank]) : GetLeaderName(PlayerInfo[playerid][pLeader]);
	 	SpeedRadarInfo[freeRadarSlot][srSpeedLimit] = slimitValue;
	 	SpeedRadarInfo[freeRadarSlot][srLocation] = LocationName;
	 	CameraInstallId[playerid] = freeRadarSlot;
		ApplyAnimation(playerid,"BOMBER","null",0.0,0,0,0,0,0);
		CameraInstallTimer[playerid] = SetTimerEx("RadarInstall", 500, true, "i", playerid);
		GetPlayerPos(playerid, CameraInstallStartPoint[playerid][0], CameraInstallStartPoint[playerid][1], CameraInstallStartPoint[playerid][2]);
	}
	else if(strcmp(key,"edit",true) == 0)
	{
		if(selectPDSlots == 0)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Вам недоступна эта функция");
    	if(IsPlayerInAnyVehicle(playerid))
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Недоступно в транспорте");
	    new NearRadar = getNearestRadar(playerid, 3);
	    if(NearRadar == -1)
	        return SendClientMessage(playerid, 0xAFAFAF00, " Рядом с вами нет камер");
		if(strcmp(SpeedRadarInfo[NearRadar][srAuthorName],GetName(playerid)) != 0)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Нельзя переместить чужую камеру");
		if(NearRadar >= (selectPDSlots-1)*5 && NearRadar < selectPDSlots*5)
		{
			for(new i=0; i < 6; i++)
			    DestroyDynamicObject(SpeedRadarInfo[NearRadar][srObjectId][i]);
            DestroyDynamic3DTextLabel(SpeedRadarInfo[NearRadar][srText3DId]);
            CameraInstallId[playerid] = NearRadar;
            ApplyAnimation(playerid,"BOMBER","null",0.0,0,0,0,0,0);
            SendClientMessage(playerid, -1, " Выберите новое положение для камеры");
			CameraInstallTimer[playerid] = SetTimerEx("RadarInstall", 500, true, "i", playerid);
			GetPlayerPos(playerid, CameraInstallStartPoint[playerid][0], CameraInstallStartPoint[playerid][1], CameraInstallStartPoint[playerid][2]);
		}
		else
		    return SendClientMessage(playerid, 0xAFAFAF00, " Нельзя переместить камеру не вашего ПД");
	}
	else if(strcmp(key,"del",true) == 0)
	{
		
	    if(selectPDSlots == 0 && AdminLvl < 3)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Вам недоступна эта функция");
    	if(IsPlayerInAnyVehicle(playerid))
	    	return SendClientMessage(playerid, 0xAFAFAF00, " Недоступно в транспорте");
	    new NearRadar = getNearestRadar(playerid, 20);
	    if(NearRadar == -1)
	        return SendClientMessage(playerid, 0xAFAFAF00, " Рядом с вами нет камер");
		if(strcmp(SpeedRadarInfo[NearRadar][srAuthorName],GetName(playerid)) != 0 && PlayerInfo[playerid][pLeader] == 0 && PlayerInfo[playerid][pRank] < 13 && AdminLvl < 3)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Удаление камер коллег доступно с 13 ранга");
		if(NearRadar >= (selectPDSlots-1)*5 && NearRadar < selectPDSlots*5)
		{
		    new string[128];
		    format(string,sizeof(string)," [Speed Cam] %s удалил камеру в районе %s",GetName(playerid),SpeedRadarInfo[NearRadar][srLocation]);
			for(new i=0; i < 6; i++)
			    DestroyDynamicObject(SpeedRadarInfo[NearRadar][srObjectId][i]);
            DestroyDynamic3DTextLabel(SpeedRadarInfo[NearRadar][srText3DId]);
            SpeedRadarInfo[NearRadar] = NULL_SpeedRadarInfo;
			SendRadioMessage(PlayerFrac, string);
		}
		else
		    return SendClientMessage(playerid, 0xAFAFAF00, " Нельзя удалить камеру не вашего ПД");
	}
	else if(strcmp(key,"info",true) == 0)
	{
	    if(selectPDSlots == 0)
		    return SendClientMessage(playerid, 0xAFAFAF00, " Вам недоступна эта функция");
        ShowPlayerDialog(playerid, 2, DIALOG_STYLE_LIST, "Скоростной радар", "[0] Нарушители за последний час\n[1] Нарушители за текущие сутки\n[2] Активные камеры", "Выбрать", "Закрыть");
        //ShowPlayerDialog(playerid, 3, DIALOG_STYLE_LIST, "Активные камеры", "[0] Нарушители за последний час\n[2] Нарушители за текущие сутки\n[3] Активные камеры", "Выбрать", "Закрыть");
	}
	else if(strcmp(key,"ticket",true) == 0)
	{
		//SetPVarInt(playerid, "params", 0);
		//GetPVarInt(playerid,"params");
        if(!SpeedRadarTicket(playerid))
            SendClientMessage(playerid, 0xAFAFAF00, " У вас нет неоплаченных штрафов");
	}
	return 1;
}
//=================================================================================

// ФУНКЦИИ
stock GetPlayerSpeed(playerid)
{
    new Float:ST[4];
    if(IsPlayerInAnyVehicle(playerid))
		GetVehicleVelocity(GetPlayerVehicleID(playerid),ST[0],ST[1],ST[2]);
	else GetPlayerVelocity(playerid,ST[0],ST[1],ST[2]);
    ST[3] = floatsqroot(floatpower(floatabs(ST[0]), 2.0) + floatpower(floatabs(ST[1]), 2.0) + floatpower(floatabs(ST[2]), 2.0)) * 100.3;
    return floatround(ST[3]);
}

public UpdateSpeedometr()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
	    if(IsPlayerInAnyVehicle(i))
	    {
			new str1[5],str2[5];
	        format(str1, sizeof(str1), "%d", GetPlayerSpeed(i));
	        format(str2, sizeof(str2), "KM/H");
	        TextDrawSetString(SpeedShow[i],str1);
	        TextDrawSetString(KMShow[i],str2);
	    }
	}
	return 1;
}

stock SendRadioMessage(frac, string[])
{
	new color = (frac == 1) ? 0x8D8DFF00 : 0x01FCFF00;
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && getPlayerFraction(i)==frac && PlayerInfo[i][pOnDuty])
            SendClientMessage(i, color, string);
    }
    return 1;
}

stock GetName(playerid)
{
  new Name[MAX_PLAYER_NAME+1];
  GetPlayerName(playerid, Name, sizeof(Name));
  return Name;
}

stock getPlayerFraction(playerid)
{
	return PlayerInfo[playerid][pLeader] == 0 ? PlayerInfo[playerid][pMember] : PlayerInfo[playerid][pLeader];
}

stock GetFractionName(fId)
{
	new frName[32] = "нет";
	switch (fId)
	{
		case 1: frName = "Police LV";
		case 2: frName = "Банда";
	}
	return frName;
}

stock GetLeaderName(fId)
{
	new frName[32] = "нет";
	switch (fId)
	{
		case 1: frName = "Шериф";
		case 2: frName = "Падре";
	}
	return frName;
}

stock GetRankName(frac, rank)
{
	new rName[32] = "нет";
	switch (frac)
	{
		case 1,3,4: // Полиция
		{
		    switch (rank)
		    {
		        case 1: rName = "Кадет";
		        case 2: rName = "Офицер";
		        case 3: rName = "Мл.сержант";
		        case 4: rName = "Сержант";
		        case 5: rName = "Прапорщик";
		        case 6: rName = "Ст.Прапорщик";
		        case 7: rName = "Мл.Лейтенант";
		        case 8: rName = "Лейтенант";
		        case 9: rName = "Ст.Лейтенант";
		        case 10: rName = "Капитан";
		        case 11: rName = "Майор";
		        case 12: rName = "Подполковник";
		        case 13: rName = "Полковник";
		    }
		}
		case 2: // Банды
		{
		    switch (rank)
		    {
		        case 1: rName = "Перро";
		        case 2: rName = "Тирадор";
		        case 3: rName = "Геттор";
		        case 4: rName = "Лас Геррас";
		        case 5: rName = "Мирандо";
		        case 6: rName = "Сабио";
		        case 7: rName = "Инвасор";
		        case 8: rName = "Тесорреро";
		        case 9: rName = "Нестро";
		    }
		}
	}
	return rName;
}

stock getPlayerCity(playerid) // LS = 0; SF = 1; LV = 2; Error = -1
{
    new Float:pX,Float:pY,Float:pZ;
	GetPlayerPos(playerid, pX, pY, pZ);
	for(new i=0; i < 9; i++)
	{
	    if(pX >= Cites[i][0] && pX <= Cites[i][2] && pY >= Cites[i][1] && pY <= Cites[i][3])
	    {
	        if(i >= 7)
	            return 0;
			else if(i >= 3)
	            return 1;
			else return 2;
	    }
	}
	return -1;
}


stock GetPlayerID(name[])
{
    new player_name[MAX_PLAYER_NAME];
    for(new i; i < MAX_PLAYERS; i++)
    {
        GetPlayerName(i, player_name, MAX_PLAYER_NAME);
        if(!strcmp(player_name, name))
            return i;
    }
    return -1;
}

stock GiveMoney(playerid, value)
{
	if(value > 0)
	{
        ResetPlayerMoney(playerid);
        PlayerInfo[playerid][pMoney] += value;
        GivePlayerMoney(playerid,PlayerInfo[playerid][pMoney]);
        return 1;
	}
	if(PlayerInfo[playerid][pMoney]+value < 0)
	    return 0;
    PlayerInfo[playerid][pMoney] += value;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid,PlayerInfo[playerid][pMoney]);
    return 1;
}

//=================================[ SPEED RADAR FUNC ]=================================

stock getNearestRadar(playerid, radius=20)
{
	new cameraid=-1,Float:pX,Float:pY,Float:pZ;
	GetPlayerPos(playerid, pX, pY, pZ);
    for(new i=0; i < 15; i++)
	{
		if(SpeedRadarInfo[i][srIsInstalled2] && GetPlayerDistanceFromPoint(playerid, SpeedRadarInfo[i][srX], SpeedRadarInfo[i][srY], SpeedRadarInfo[i][srZ]) < radius) {
		    cameraid = i;
		    break;
		 }
	}
	return cameraid;
}

stock updateRadarAuthorName(oldName[MAX_PLAYER_NAME+1], nextName[MAX_PLAYER_NAME+1])
{
	for(new i=0; i < 15; i++)
	{
	    if(strcmp(SpeedRadarInfo[i][srAuthorName],oldName) == 0)
	    {
	        new Text3DString[512], FracAuthorName[6];
			if(i < 5)
			    FracAuthorName = "LSPD";
			else if(i < 10)
				FracAuthorName = "SFPD";
			else if(i < 15)
				FracAuthorName = "LVPD";
			format(Text3DString,sizeof(Text3DString),"{00A86B}Камера на {FFFFFF}%i\n{00A86B}Поставил: {FFFFFF}%s / %s [%s]", SpeedRadarInfo[i][srSpeedLimit],FracAuthorName,nextName,SpeedRadarInfo[i][srAuthorRank]);
			UpdateDynamic3DTextLabelText(SpeedRadarInfo[i][srText3DId], -1, Text3DString);
			SpeedRadarInfo[i][srAuthorName] = nextName;
		}
	}
	for(new i=0; i < srTicketsIndex; i++)
	{
		if(strcmp(SpeedRadarTickets[i][srtPlayerName],oldName) == 0)
		    SpeedRadarTickets[i][srtPlayerName] = nextName;
	}
	return 1;
}

stock ResetAllSpeedRadar()
{
    for(new i=0; i < 15; i++)
    {
        for(new j=0; j < 6; j++)
			 DestroyDynamicObject(SpeedRadarInfo[i][srObjectId][j]);
        DestroyDynamic3DTextLabel(SpeedRadarInfo[i][srText3DId]);
		SpeedRadarInfo[i] = NULL_SpeedRadarInfo;
	}
	for(new i=0; i < srTicketsIndex; i++)
	{
		SpeedRadarTickets[i] = NULL_SpeedRadarTickets;
	}
	srTicketsIndex = 0;
	return 1;
}

stock SpeedRadarTicketsPayDay()
{
	for(new i=0; i < srTicketsIndex; i++)
	{
		if(!SpeedRadarTickets[i][srtAfterPayDay])
			SpeedRadarTickets[i][srtAfterPayDay] = true;
	}
	return 1;
}

stock SpeedRadarTicket(playerid)
{
	static const fmt_str[] = "%s[%i] %s\t%i (+%i)\t%i вирт\n";
	new dialog_header[35] = "Автомобиль\tСкорость\tШтраф\n",
    string[sizeof(dialog_header) + (sizeof(fmt_str) + (-2) + (-2 + 4) + (-2 + 32) + (-2 + 3) + (-2 + 3) + (-2 + 5)) * 32],
	TicketsCount = 0;
    string = dialog_header;
    for(new i=0; i < srTicketsIndex; i++)
	{
	    if(strcmp(SpeedRadarTickets[i][srtPlayerName],GetName(playerid)) == 0)
				format(string, sizeof(string), fmt_str, string, ++TicketsCount, VehicleNames[SpeedRadarTickets[i][srtCar]-400], SpeedRadarTickets[i][srtPlayerSpeed], SpeedRadarTickets[i][srtPlayerSpeed]-SpeedRadarTickets[i][srtSpeedLimit], 2000 * ((SpeedRadarTickets[i][srtPlayerSpeed]-SpeedRadarTickets[i][srtSpeedLimit]) / 10));
	}
	if(TicketsCount > 0) {
	    ShowPlayerDialog(playerid, 4, DIALOG_STYLE_TABLIST_HEADERS, "Штрафы за превышение скорости", string, "Оплатить", "Закрыть");
	    string = "\0";
	    return 1;
	}
	return 0;
}

public RadarInstall(playerid)
{
	new Float:Angle,Float:cpX,Float:cpY,Float:pX,Float:pY,Float:pZ;
	GetPlayerFacingAngle(playerid, Angle);
	GetPlayerPos(playerid, pX, pY, pZ);
	if (GetPlayerDistanceFromPoint(playerid,CameraInstallStartPoint[playerid][0], CameraInstallStartPoint[playerid][1], CameraInstallStartPoint[playerid][2]) > 10 || IsPlayerInAnyVehicle(playerid))
	{
  		SendClientMessage(playerid, 0xAFAFAF00, " Установка радара прервана");
  		if(SpeedRadarInfo[CameraInstallId[playerid]][srIsInstalled2])
		{
			new string[128];
		    format(string,sizeof(string)," [Speed Cam] %s удалил камеру в районе %s",GetName(playerid),SpeedRadarInfo[CameraInstallId[playerid]][srLocation]);
			SendRadioMessage(getPlayerFraction(playerid), string);
		}
    	KillTimer(CameraInstallTimer[playerid]);
		CameraInstallTimer[playerid] = 0;
		DisablePlayerCheckpoint(CameraInstallTimer[playerid]);
  		SpeedRadarInfo[CameraInstallId[playerid]] = NULL_SpeedRadarInfo;
    	return 0;
	}
	SpeedRadarInfo[CameraInstallId[playerid]][srAngle] = Angle;
	Angle *= 3.14159265/180.0;
	cpX = pX - floatsin(Angle)*2.5;
	cpY = pY + floatcos(Angle)*2.5;
	GameTextForPlayer(playerid, "~g~Pess~w~ ~k~~PED_DUCK~", 550, 3);
	SpeedRadarInfo[CameraInstallId[playerid]][srX] = cpX;
	SpeedRadarInfo[CameraInstallId[playerid]][srY] = cpY;
	SpeedRadarInfo[CameraInstallId[playerid]][srZ] = pZ;
	SetPlayerCheckpoint(playerid, cpX, cpY, pZ, 1.5);
	return 1;
}

public CameraPlace(playerid)
{
	new cameraid = CameraInstallId[playerid];
	CameraInstallId[playerid] = -1;
	new Float:RadarBasicX = SpeedRadarInfo[cameraid][srX],
	Float:RadarBasicY = SpeedRadarInfo[cameraid][srY],
	Float:RadarBasicZ = SpeedRadarInfo[cameraid][srZ]-1,
	Float:RadarBasicAngle = SpeedRadarInfo[cameraid][srAngle],
	tmpobjid,
	slimitText[4],
	Text3DString[512],
	FracAuthorName[6];
	if(cameraid < 5)
	    FracAuthorName = "LSPD";
	else if(cameraid < 10)
		FracAuthorName = "SFPD";
	else if(cameraid < 15)
		FracAuthorName = "LVPD";
	format(slimitText,sizeof(slimitText),"%i", SpeedRadarInfo[cameraid][srSpeedLimit]);
	format(Text3DString,sizeof(Text3DString),"{00A86B}Камера на {FFFFFF}%i\n{00A86B}Поставил: {FFFFFF}%s / %s [%s]", SpeedRadarInfo[cameraid][srSpeedLimit],FracAuthorName,SpeedRadarInfo[cameraid][srAuthorName],SpeedRadarInfo[cameraid][srAuthorRank]);
	// Маппинг
    tmpobjid = CreateDynamicObject(19967, RadarBasicX+0.028808, RadarBasicY-0.001709, RadarBasicZ+0.657765, 0.0, 0.0, 0.0+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterial(tmpobjid, 2, 1714, "cj_office", "white32", 0xFFE31E25);
	SpeedRadarInfo[cameraid][srObjectId][0] = tmpobjid;
	tmpobjid = CreateDynamicObject(19955, RadarBasicX+0.024902, RadarBasicY-0.003762, RadarBasicZ+0.659169, 0.0, 0.0, 0.0+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterial(tmpobjid, 1, -1, "none", "none", 0x00FFFFFF);
	SetDynamicObjectMaterial(tmpobjid, 2, 1714, "cj_office", "white32", 0xFFEEEEEE);
	SpeedRadarInfo[cameraid][srObjectId][1] = tmpobjid;
	tmpobjid = CreateDynamicObject(19477, RadarBasicX+0.02539, RadarBasicY-0.029588, RadarBasicZ+3.265232, 0.0, 0.0, -90.0+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterialText(tmpobjid, 0, slimitText, 130, "Arial Narrow", 85, 1, 0xFF000000, 0x00000000, 1);
	SpeedRadarInfo[cameraid][srObjectId][2] = tmpobjid;
	tmpobjid = CreateDynamicObject(18880, RadarBasicX+0.140136, RadarBasicY-0.001465, RadarBasicZ-3.99221, 0.0, 0.0, 0.0+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterial(tmpobjid, 2, -1, "none", "none", 0x00FFFFFF);
	SpeedRadarInfo[cameraid][srObjectId][3] = tmpobjid;
	tmpobjid = CreateDynamicObject(3031, RadarBasicX+0.628174, RadarBasicY-0.026855, RadarBasicZ+1.541077, 0.0, 0.0, -90.0+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterial(tmpobjid, 0, -1, "none", "none", 0x00FFFFFF);
	SetDynamicObjectMaterial(tmpobjid, 1, -1, "none", "none", 0x00FFFFFF);
	SpeedRadarInfo[cameraid][srObjectId][4] = tmpobjid;
	tmpobjid = CreateDynamicObject(1237, RadarBasicX, RadarBasicY, RadarBasicZ, 0.000000, 0.000045, 0.000000+RadarBasicAngle, -1, -1, -1, 300.00, 300.00);
	SetDynamicObjectMaterial(tmpobjid, 0, 10778, "airportcpark_sfse", "ws_boothpanel", 0xFFFFFFFF);
	SpeedRadarInfo[cameraid][srObjectId][5] = tmpobjid;
	// 3DText
    SpeedRadarInfo[cameraid][srText3DId] = CreateDynamic3DTextLabel(Text3DString, -1,SpeedRadarInfo[cameraid][srX], SpeedRadarInfo[cameraid][srY], SpeedRadarInfo[cameraid][srZ],40);
	// Динамическая зона
	SpeedRadarInfo[cameraid][srNoticeZone] = CreateDynamicCircle(RadarBasicX, RadarBasicY, 80, 0, 0, -1);
	SpeedRadarInfo[cameraid][srTicketZone] = CreateDynamicCircle(RadarBasicX, RadarBasicY, 20, 0, 0, -1);
    
    if(!SpeedRadarInfo[cameraid][srIsInstalled2])
    {
	    new UserFraction = PlayerInfo[playerid][pLeader] == 0 ? PlayerInfo[playerid][pMember] : PlayerInfo[playerid][pLeader],
	    string[128];
	    format(string,sizeof(string)," [Speed Cam] %s создал камеру на %s км/ч в местности %s",GetName(playerid),slimitText,SpeedRadarInfo[cameraid][srLocation]);
	    SendRadioMessage(UserFraction, string);
	    SpeedRadarInfo[cameraid][srIsInstalled2] = true;
    }
	return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	if(IsPlayerInAnyVehicle(playerid))
	{
	    for(new i=0; i < 15; i++)
		{
			if(areaid == SpeedRadarInfo[i][srNoticeZone])
			{
			    new fmt_str[] = " На данном участке дороги ограничение скорости {FF6600}%i{FFFFFF} км/ч. Будь внимателен и снизь скорость!",
				string[sizeof(fmt_str) + (-2 + 3)];
				format(string,sizeof(string),fmt_str,SpeedRadarInfo[i][srSpeedLimit]);
	            SendClientMessage(playerid,-1,string);
			}
			else if(areaid == SpeedRadarInfo[i][srTicketZone])
			{
			    new PlayerFrac = getPlayerFraction(playerid);
			    if(PlayerFrac == 1 || PlayerFrac == 3 || PlayerFrac == 4) // Проверка на гос. фракцию. Их не штрафуем
			        return 1;
				new PlayerSpeed = GetPlayerSpeed(playerid),
				OverSpeed = PlayerSpeed - SpeedRadarInfo[i][srSpeedLimit] > 0 ? PlayerSpeed - SpeedRadarInfo[i][srSpeedLimit] : 0,
				TicketAmount = OverSpeed ? 2000 * (OverSpeed / 10) : 0;
				if(TicketAmount > 0)
				{
					new string[128],RadarPD;
		            format(string,sizeof(string)," [Speed Cam] Камера в %s засекла нарушение. Автомобиль: %s. Водитель: %s", SpeedRadarInfo[i][srLocation],VehicleNames[GetVehicleModel(GetPlayerVehicleID(playerid))-400],GetName(playerid));
		            if(i < 5)
		            {
		                RadarPD = 3; // id LSPD
		                SpeedRadarTickets[srTicketsIndex][srtPolice] = 1;
		            }
		            else if(i < 10)
		            {
		                RadarPD = 4; // id SFPD
		                SpeedRadarTickets[srTicketsIndex][srtPolice] = 2;
		            }
		            else if(i < 15)
		            {
		                RadarPD = 1; // id LVPD
		                SpeedRadarTickets[srTicketsIndex][srtPolice] = 3;
		            }
		            SendRadioMessage(RadarPD, string);
		            PlayerPlaySound(playerid, 1132, 0.0, 0.0, 0.0);
		            format(string,sizeof(string)," SMS: Ваш автомобиль нарушил скоростной режим на %i км/ч. Отправитель: Государство", OverSpeed);
					SendClientMessage(playerid, 0xFFFF0000, string);
					format(string,sizeof(string)," SMS: Штраф в размере {FF6600}%i{FFFF00} вирт будет снят с вашего банковского счёта. Отправитель: Государство", TicketAmount);
					SendClientMessage(playerid, 0xFFFF0000, string);
					SendClientMessage(playerid, -1, " (( Для получения дополнительной информации и оплаты штрафа введите: /sradar ticket ))");
					SpeedRadarTickets[srTicketsIndex][srtPlayerName] = GetName(playerid);
					SpeedRadarTickets[srTicketsIndex][srtCar] = GetVehicleModel(GetPlayerVehicleID(playerid));
					SpeedRadarTickets[srTicketsIndex][srtSpeedLimit] = SpeedRadarInfo[i][srSpeedLimit];
					SpeedRadarTickets[srTicketsIndex][srtPlayerSpeed] = PlayerSpeed;
					SpeedRadarTickets[srTicketsIndex][srtAfterPayDay] = false;
					srTicketsIndex++;
	            }
			}
		}
	}
	return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	return 1;
}

//======================================================================================
