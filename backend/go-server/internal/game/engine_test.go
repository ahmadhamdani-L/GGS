package game

import (
	"testing"
)

// Helper to create PlayerInfo slice from names/ids
func createPlayerInfos(names, ids []string) []PlayerInfo {
	infos := make([]PlayerInfo, len(names))
	for i := range names {
		infos[i] = PlayerInfo{
			ID:          ids[i],
			DisplayName: names[i],
			AvatarID:    (i % 4) + 1,
		}
	}
	return infos
}

func TestCreateGame(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	
	if game == nil {
		t.Fatal("CreateGame returned nil")
	}
	
	if game.ID == "" {
		t.Error("Game ID should not be empty")
	}
	
	if len(game.Players) != 8 {
		t.Errorf("Expected 8 players, got %d", len(game.Players))
	}
	
	if game.Phase != PhaseLobby {
		t.Errorf("Initial phase should be LOBBY, got %s", game.Phase)
	}
}

func TestStartGame(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	if game.Phase != PhaseRoleReveal {
		t.Errorf("Phase after StartGame should be ROLE_REVEAL, got %s", game.Phase)
	}
	
	// Check that roles were assigned
	rolesAssigned := 0
	for _, p := range game.Players {
		if p.Role != "" {
			rolesAssigned++
		}
	}
	
	if rolesAssigned != 8 {
		t.Errorf("Expected 8 roles assigned, got %d", rolesAssigned)
	}
}

func TestGetRoleTeam(t *testing.T) {
	tests := []struct {
		role     Role
		expected Team
	}{
		{RoleWerewolf, TeamRed},
		{RoleWitch, TeamRed},
		{RoleSeer, TeamBlue},
		{RoleDoctor, TeamBlue},
		{RoleVillager, TeamBlue},
	}
	
	for _, tt := range tests {
		t.Run(string(tt.role), func(t *testing.T) {
			team := GetRoleTeam(tt.role)
			if team != tt.expected {
				t.Errorf("GetRoleTeam(%s) = %s, want %s", tt.role, team, tt.expected)
			}
		})
	}
}

func TestConfirmRoleReveal(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	// Confirm all players
	for _, id := range ids {
		game = ConfirmRoleReveal(game, id)
	}
	
	// After all confirm, phase should be night (either NIGHT or NIGHT_START)
	if !game.Phase.IsNight() {
		t.Errorf("Phase after all confirms should be a night phase, got %s", game.Phase)
	}
}

func TestStartNightPhase(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	game = StartNightPhase(game)
	
	// Phase should be a night phase
	if !game.Phase.IsNight() {
		t.Errorf("Phase after StartNightPhase should be a night phase, got %s", game.Phase)
	}
}

func TestCheckWinCondition_BlueWins(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	// Kill all werewolves and witch (Red Team)
	for i := range game.Players {
		if game.Players[i].Role == RoleWerewolf || game.Players[i].Role == RoleWitch {
			game.Players[i].IsAlive = false
		}
	}
	
	// Use internal function via test (since checkWinCondition is unexported)
	winner := checkWinCondition(game)
	if winner == nil {
		t.Error("Game should be done when all red team dead")
	} else if *winner != TeamBlue {
		t.Errorf("Winner should be Blue, got %s", *winner)
	}
}

func TestCheckWinCondition_RedWins(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	// Kill blue team players until werewolves >= blue
	blueKilled := 0
	for i := range game.Players {
		team := GetRoleTeam(game.Players[i].Role)
		if team == TeamBlue && blueKilled < 4 {
			game.Players[i].IsAlive = false
			blueKilled++
		}
	}
	
	// Use internal function
	winner := checkWinCondition(game)
	if winner == nil {
		t.Error("Game should be done when red >= remaining blue")
	} else if *winner != TeamRed {
		t.Errorf("Winner should be Red, got %s", *winner)
	}
}

func TestCheckWinCondition_GameContinues(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	// Don't kill anyone - game should continue
	winner := checkWinCondition(game)
	if winner != nil {
		t.Errorf("Winner should be nil (game continues), got %s", *winner)
	}
}

func TestFilterStateForPlayer(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	game = StartGame(game)
	
	// Get filtered state for first player
	filtered := FilterStateForPlayer(game, ids[0])
	
	if filtered == nil {
		t.Fatal("FilterStateForPlayer returned nil")
	}
	
	// Find self in filtered state
	var selfPlayer *PlayerState
	for i := range filtered.Players {
		if filtered.Players[i].ID == ids[0] {
			selfPlayer = &filtered.Players[i]
			break
		}
	}
	
	if selfPlayer == nil {
		t.Fatal("Could not find self in filtered state")
	}
	
	// Player should see their own role
	if selfPlayer.Role == "" {
		t.Error("Player should see their own role")
	}
}

func TestFindPlayer(t *testing.T) {
	names := []string{"P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"}
	ids := []string{"id1", "id2", "id3", "id4", "id5", "id6", "id7", "id8"}
	
	game := CreateGame(createPlayerInfos(names, ids))
	
	// Find existing player
	player := findPlayer(game, "id1")
	if player == nil {
		t.Error("findPlayer should find existing player")
	}
	if player.ID != "id1" {
		t.Errorf("Found wrong player: %s", player.ID)
	}
	
	// Find non-existing player
	notFound := findPlayer(game, "nonexistent")
	if notFound != nil {
		t.Error("findPlayer should return nil for non-existing player")
	}
}

func TestDistributeRoles(t *testing.T) {
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
	
	// Count each role
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
