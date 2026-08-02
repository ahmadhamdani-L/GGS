package game

import (
	"testing"
)

func TestCreateGame_ValidRoles(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('1'+i)), DisplayName: "P" + string(rune('1'+i))}
	}
	g := CreateGame(players)
	if g == nil {
		t.Fatal("CreateGame returned nil")
	}
	if len(g.Players) != 8 {
		t.Errorf("Expected 8 players, got %d", len(g.Players))
	}
	if g.Phase != PhaseLobby {
		t.Errorf("Expected LOBBY phase, got %s", g.Phase)
	}
}

func TestStartGame_AssignsRoles(t *testing.T) {
	players := make([]PlayerInfo, 10)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)

	if g.Phase != PhaseRoleReveal {
		t.Errorf("Expected ROLE_REVEAL, got %s", g.Phase)
	}

	roleCounts := make(map[Role]int)
	for _, p := range g.Players {
		if p.Role == "" {
			t.Error("Player has empty role after StartGame")
		}
		roleCounts[p.Role]++
	}
	// 10 players: 3 WW, 2 Seer, 1 Doctor, 1 Witch, 3 Villager
	if roleCounts[RoleWerewolf] != 3 {
		t.Errorf("Expected 3 werewolves, got %d", roleCounts[RoleWerewolf])
	}
	if roleCounts[RoleSeer] != 2 {
		t.Errorf("Expected 2 seers, got %d", roleCounts[RoleSeer])
	}
}

func TestConfirmRoleReveal_AllConfirmed(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)

	// Mark all bots as confirmed
	for i := range g.Players {
		g.Players[i].IsBot = false
	}

	// Confirm all players
	for _, p := range g.Players {
		g = ConfirmRoleReveal(g, p.ID)
	}

	if g.Phase != PhaseNight {
		t.Errorf("Expected NIGHT after all confirmed, got %s", g.Phase)
	}
}

func TestCastVote_RejectsDeadPlayer(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}

	// Kill a player
	g.Players[2].IsAlive = false

	// Try to vote for dead player
	_, err := CastVote(g, g.Players[0].ID, g.Players[2].ID)
	if err == nil {
		t.Error("Expected error voting for dead player, got nil")
	}
}

func TestCastVote_RejectsSelfVote(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}

	// Try to vote for self
	_, err := CastVote(g, g.Players[0].ID, g.Players[0].ID)
	if err == nil {
		t.Error("Expected error voting for self, got nil")
	}
}

func TestCastVote_AllowsSkip(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}

	// Vote with empty target (skip)
	g2, err := CastVote(g, g.Players[0].ID, "")
	if err != nil {
		t.Errorf("Expected skip vote to succeed, got error: %v", err)
	}
	if g2.Votes.Votes[g.Players[0].ID] != "" {
		t.Error("Skip vote should store empty string")
	}
}

func TestCastVote_RejectsInvalidTarget(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}

	// Vote for non-existent player
	_, err := CastVote(g, g.Players[0].ID, "nonexistent-id")
	if err == nil {
		t.Error("Expected error for invalid target ID")
	}
}

func TestCastVote_RejectsDeadVoter(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}

	// Kill voter
	g.Players[0].IsAlive = false

	_, err := CastVote(g, g.Players[0].ID, g.Players[1].ID)
	if err == nil {
		t.Error("Expected error for dead voter")
	}
}

func TestGetRoleTeam(t *testing.T) {
	tests := []struct {
		role Role
		team Team
	}{
		{RoleWerewolf, TeamRed},
		{RoleWitch, TeamRed},
		{RoleSeer, TeamBlue},
		{RoleDoctor, TeamBlue},
		{RoleVillager, TeamBlue},
	}
	for _, tt := range tests {
		if got := GetRoleTeam(tt.role); got != tt.team {
			t.Errorf("GetRoleTeam(%s) = %s, want %s", tt.role, got, tt.team)
		}
	}
}

func TestDistributeRoles_CorrectCount(t *testing.T) {
	config := map[Role]int{
		RoleWerewolf: 2,
		RoleSeer:     2,
		RoleDoctor:   1,
		RoleWitch:    1,
		RoleVillager: 2,
	}
	roles := distributeRoles(config, 8)
	if len(roles) != 8 {
		t.Errorf("Expected 8 roles, got %d", len(roles))
	}

	counts := make(map[Role]int)
	for _, r := range roles {
		counts[r]++
	}
	for role, expected := range config {
		if counts[role] != expected {
			t.Errorf("Expected %d %s, got %d", expected, role, counts[role])
		}
	}
}

func TestNightAction_WerewolfCannotTargetSelf(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find a werewolf
	var wolfID string
	for _, p := range g.Players {
		if p.Role == RoleWerewolf {
			wolfID = p.ID
			break
		}
	}

	// Try to target another werewolf (should fail — werewolf can't target werewolf)
	var otherWolfID string
	for _, p := range g.Players {
		if p.Role == RoleWerewolf && p.ID != wolfID {
			otherWolfID = p.ID
			break
		}
	}

	_, err := SubmitNightActionSequential(g, wolfID, otherWolfID, false, nil)
	if err == nil {
		t.Error("Expected error when werewolf targets another werewolf")
	}
}
