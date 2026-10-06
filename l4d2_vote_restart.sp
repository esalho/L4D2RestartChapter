#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SURVIVOR 2

#define VOTE_DURATION 20

public Plugin myinfo =
{
    name        = "Vote Restart Chapter",
    author      = "Gilbert",
    description = "Unanimous survivor vote to restart the current chapter",
    version     = "0.3",
    url         = ""
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_restart", Cmd_VoteRestart, "Vote to restart the chapter");
}

bool IsVoteAllowedMode()
{
    int mode = L4D_GetGameModeType();
    return mode == GAMEMODE_COOP || mode == GAMEMODE_SURVIVAL;
}

bool IsEligibleVoter(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && !IsFakeClient(client)
        && GetClientTeam(client) == TEAM_SURVIVOR;
}

Action Cmd_VoteRestart(int client, int args)
{
    if (!IsVoteAllowedMode())
    {
        ReplyToCommand(client, "[SM] Restart chapter votes are not available in this game mode.");
        PrintToServer("[L4D2VoteRestart] Player attempted to start a restart chapter vote in an incompatible game mode.");
        return Plugin_Handled;
    }

    if (!IsEligibleVoter(client))
    {
        ReplyToCommand(client, "[SM] Only active survivors can start a restart chapter vote.");
        PrintToServer("[L4D2VoteRestart] Player attempted to start a restart vote without being an eligible voter.");
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        ReplyToCommand(client, "[SM] A vote is already in progress.");
        PrintToServer("[L4D2VoteRestart] Player attempted to start a restart chapter vote while one was in progress.");
        return Plugin_Handled;
    }

    int delay = CheckVoteDelay();
    if (delay > 0)
    {
        ReplyToCommand(client, "[SM] Please wait %d seconds before starting another vote.", delay);
        PrintToServer("[L4D2VoteRestart] Player attempted to start a restart chapter vote too quickly.");
        return Plugin_Handled;
    }

    int[] voters = new int[MaxClients];
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsEligibleVoter(i))
        {
            voters[count++] = i;
        }
    }

    Menu menu = new Menu(MenuHandler);
    menu.VoteResultCallback = OnVoteResult;
    menu.SetTitle("Restart the chapter?");
    menu.AddItem("yes", "Yes");
    menu.AddItem("no", "No");
    menu.ExitButton = false;

    PrintToChatAll("[SM] %N started a vote to restart the chapter.", client);
    PrintToServer("[L4D2VoteRestart] Vote to restart the chapter started by player %N.", client);

    menu.DisplayVote(voters, count, VOTE_DURATION);
    return Plugin_Handled;
}

int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
    {
        PrintToChatAll("[SM] Restart vote failed: nobody voted.");
        PrintToServer("[L4D2VoteRestart] Restart vote failed: nobody voted.");
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void OnVoteResult(Menu menu, int numVotes, int numClients,
                  const int[][] clientInfo, int numItems, const int[][] itemInfo)
{
    int yes = 0;
    int no = 0;
    char info[8];

    for (int i = 0; i < numClients; i++)
    {
        int voter = clientInfo[i][VOTEINFO_CLIENT_INDEX];
        int item  = clientInfo[i][VOTEINFO_CLIENT_ITEM];

        if (!IsEligibleVoter(voter))
        {
            continue;
        }

        menu.GetItem(item, info, sizeof(info));
        if (StrEqual(info, "yes"))
        {
            yes++;
        }
        else
        {
            no++;
        }
    }

    int eligible = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsEligibleVoter(i))
        {
            eligible++;
        }
    }

    if (eligible > 0 && no == 0 && yes == eligible)
    {
        PrintToChatAll("[SM] Restart chapter vote passed (%d/%d). Restarting chapter...", yes, eligible);
        PrintToServer("[L4D2VoteRestart] Restart chapter vote passed (%d/%d). Restarting chapter...", yes, eligible);
        RestartChapter();
    }
    else
    {
        PrintToChatAll("[SM] Restart chapter vote failed (%d yes, %d no, %d did not vote).",
                       yes, no, eligible - yes - no);
        PrintToServer("[L4D2VoteRestart] Restart chapter vote failed (%d yes, %d no, %d did not vote).",
                      yes, no, eligible - yes - no);
    }
}

void RestartChapter()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
        {
            ForcePlayerSuicide(i);
        }
    }
}
