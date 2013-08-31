// ====[ VARIABLES ]============================================
enum
{
	Announce,
	HideChat,
	Purge,
	BonusRound,
	MinPlayers,
	StartPoints,
	MinPoints,
	MeleeMultipler,

	Points_TK_Penalty,
	Points_Suicide,
	Points_Capture,
	Points_Block,
	Points_Explode,
	Points_Plant,
	Points_Defuse,
	Points_Headshot,
	Points_RoundWin,

	GG_LevelSteal,
	GG_LevelDown,
	GG_RoundWin,

	ConVar_Size
};

enum ValueType
{
	ValueType_Bool,
	ValueType_Int
};

enum ConVar
{
	Handle:ConVarHandle, // Handle of the convar
	ValueType:Type,      // Type of value (int, bool)
	any:Value            // The value
};

new GetConVar[ConVar_Size][ConVar];

/* LoadConVars()
 *
 * Initialze cvars for plugin.
 * --------------------------------------------------------------------- */
LoadConVars()
{
	// Create CoVars
	CreateConVar("sm_dodstats_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	AddConVar(Announce,          ValueType_Bool, CreateConVar("dodstats_announce",         "1",    "Whether or not print player's information when connected ( points and grade )",          FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(HideChat,          ValueType_Bool, CreateConVar("dodstats_hidechat",         "0",    "Whether or not hide chat triggers ( rank/stats/session/notify/top/topgrades/topgg )",    FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(Purge,             ValueType_Int,  CreateConVar("dodstats_purge",            "0",    "Number of days to delete inactive players from the database\nSet to 0 to disable purge", FCVAR_PLUGIN, true, 0.0));
	AddConVar(BonusRound,        ValueType_Bool, CreateConVar("dodstats_bonusround",       "1",    "Whether or not enable stats during bonusround",                                          FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(MinPlayers,        ValueType_Int,  CreateConVar("dodstats_minplayers",       "4",    "Minimum players required to record stats\nSet to 0 to disable this feature",             FCVAR_PLUGIN, true, 0.0, true, 32.0));
	AddConVar(StartPoints,       ValueType_Int,  CreateConVar("dodstats_start_points",     "1000", "Sets the starting points for a new player",                                              FCVAR_PLUGIN, true, 0.0));
	AddConVar(MinPoints,         ValueType_Int,  CreateConVar("dodstats_points_min",       "2",    "Sets the minimum points to take on kill\nSet 0 to disable kill points at all",           FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(MeleeMultipler,    ValueType_Int,  CreateConVar("dodstats_multipler_melee",  "2",    "Sets the multipler for killing by melee weapons (such as knife, spade and punch)",       FCVAR_PLUGIN, true, 1.0, true, 25.0));

	AddConVar(Points_TK_Penalty, ValueType_Int,  CreateConVar("dodstats_points_teamkill",  "8",    "Amount of points to take on team kill (TNT kills will be ignored)",                      FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Suicide,    ValueType_Int,  CreateConVar("dodstats_points_suicide",   "5",    "Amount of points to take on suicide",                                                    FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Capture,    ValueType_Int,  CreateConVar("dodstats_points_capture",   "3",    "Amount of points to give for capturing area",                                            FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Block,      ValueType_Int,  CreateConVar("dodstats_points_block",     "3",    "Amount of points to give for blocking capture",                                          FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Explode,    ValueType_Int,  CreateConVar("dodstats_points_explode",   "3",    "Amount of points to give for exploding an objective",                                    FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Plant,      ValueType_Int,  CreateConVar("dodstats_points_plant",     "3",    "Amount of points to give for planting a TNT",                                            FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Defuse,     ValueType_Int,  CreateConVar("dodstats_points_defuse",    "3",    "Amount of points to give for defusing a TNT",                                            FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_Headshot,   ValueType_Int,  CreateConVar("dodstats_points_headshot",  "1",    "Amount of points to add for a headshot kill",                                            FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(Points_RoundWin,   ValueType_Int,  CreateConVar("dodstats_points_victory",   "1",    "Amount of points to give to all members of team which has won the round",                FCVAR_PLUGIN, true, 0.0, true, 25.0));

	AddConVar(GG_LevelSteal,     ValueType_Int,  CreateConVar("dodstats_gg_levelsteal",    "5",    "Amount of points to give for stealing a level\nRequires GG 4.2 and newer",               FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(GG_LevelDown,      ValueType_Int,  CreateConVar("dodstats_gg_leveldown",     "5",    "Amount of points to take on level lost\nRequires GG 4.2 and newer",                      FCVAR_PLUGIN, true, 0.0, true, 25.0));
	AddConVar(GG_RoundWin,       ValueType_Int,  CreateConVar("dodstats_gg_victorypoints", "10",   "Amount of points to give to a GunGame winner\nRequires GG 4.2 and newer",                FCVAR_PLUGIN, true, 0.0, true, 25.0));
}

/* AddConVar()
 *
 * Used to add a convar into the convar list.
 * --------------------------------------------------------------------- */
AddConVar(conVar, ValueType:type, Handle:conVarHandle)
{
	GetConVar[conVar][ConVarHandle] = conVarHandle;
	GetConVar[conVar][Type] = type;

	UpdateConVarValue(conVar);

	HookConVarChange(conVarHandle, OnConVarChange);
}

/* UpdateConVarValue()
 *
 * Updates the internal convar values.
 * --------------------------------------------------------------------- */
UpdateConVarValue(conVar)
{
	switch (GetConVar[conVar][Type])
	{
		case ValueType_Bool: GetConVar[conVar][Value] = GetConVarBool(GetConVar[conVar][ConVarHandle]);
		case ValueType_Int:  GetConVar[conVar][Value] = GetConVarInt (GetConVar[conVar][ConVarHandle]);
	}
}

/* OnConVarChange()
 *
 * Updates the stored convar value if the convar's value change.
 * --------------------------------------------------------------------- */
public OnConVarChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	for (new i = 0; i < ConVar_Size; i++)
	{
		if (conVar == GetConVar[i][ConVarHandle])
		{
			UpdateConVarValue(i);
		}
	}
}