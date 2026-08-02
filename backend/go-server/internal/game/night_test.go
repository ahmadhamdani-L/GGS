package game

import (
	"testing"
)

func TestStartNightPhase(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	if g.Phase != PhaseNight {
		t.Errorf("Expected NIGHT phase, got %s", g.Phase)
	}
	if g.NightActions.WolfVotes == nil {
		t.Error("WolfVotes map should be initialized")
	}
	if g.NightActions.SubmittedPlayers == nil {
		t.Error("SubmittedPlayers map should be initialized")
	}
}

func TestSubmitNightAction_WerewolfTarget(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find wolf and valid target
	var wolfID, targetID string
	for _, p := range g.Players {
		if p.Role == RoleWerewolf && wolfID == "" {
			wolfID = p.ID
		} else if p.Role != RoleWerewolf && targetID == "" {
			targetID = p.ID
		}
	}

	g2, err := SubmitNightActionSequential(g, wolfID, targetID, false, nil)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if !g2.NightActions.SubmittedPlayers[wolfID] {
		t.Error("Wolf should be marked as submitted")
	}
	if g2.NightActions.WolfVotes[wolfID] != targetID {
		t.Error("Wolf vote not recorded")
	}
}

func TestSubmitNightAction_DoctorProtect(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find doctor
	var doctorID, targetID string
	for _, p := range g.Players {
		if p.Role == RoleDoctor {
			doctorID = p.ID
		} else if targetID == "" {
			targetID = p.ID
		}
	}
	if doctorID == "" {
		t.Skip("No doctor in this game composition")
	}

	g2, err := SubmitNightActionSequential(g, doctorID, targetID, false, nil)
	if err != nil {
		t.Fatalf("Doctor protect failed: %v", err)
	}
	if g2.NightActions.DoctorTarget == nil || *g2.NightActions.DoctorTarget != targetID {
		t.Error("Doctor target not recorded")
	}
}

func TestSubmitNightAction_DoctorMaxProtects(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find doctor and exhaust protects
	var doctorID string
	for i, p := range g.Players {
		if p.Role == RoleDoctor {
			doctorID = p.ID
			g.Players[i].DoctorProtectsUsed = 3 // Max reached
			break
		}
	}
	if doctorID == "" {
		t.Skip("No doctor")
	}

	_, err := SubmitNightActionSequential(g, doctorID, "pA", false, nil)
	if err == nil {
		t.Error("Expected error when doctor has no protects remaining")
	}
}

func TestSubmitNightAction_SeerGetsTeamResult(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find seer and a werewolf target
	var seerID, wolfTargetID string
	for _, p := range g.Players {
		if p.Role == RoleSeer && seerID == "" {
			seerID = p.ID
		}
		if p.Role == RoleWerewolf && wolfTargetID == "" {
			wolfTargetID = p.ID
		}
	}
	if seerID == "" {
		t.Skip("No seer")
	}

	g2, err := SubmitNightActionSequential(g, seerID, wolfTargetID, false, nil)
	if err != nil {
		t.Fatalf("Seer action failed: %v", err)
	}
	if g2.NightActions.SeerResult == nil {
		t.Fatal("Seer result should not be nil")
	}
	if *g2.NightActions.SeerResult != "red" {
		t.Errorf("Expected 'red' for werewolf target, got '%s'", *g2.NightActions.SeerResult)
	}
}

func TestSubmitNightAction_AlreadySubmitted(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	var wolfID, t1, t2 string
	for _, p := range g.Players {
		if p.Role == RoleWerewolf && wolfID == "" {
			wolfID = p.ID
		} else if p.Role != RoleWerewolf {
			if t1 == "" {
				t1 = p.ID
			} else if t2 == "" {
				t2 = p.ID
			}
		}
	}

	// First submit
	g, _ = SubmitNightActionSequential(g, wolfID, t1, false, nil)
	// Second submit should fail
	_, err := SubmitNightActionSequential(g, wolfID, t2, false, nil)
	if err == nil {
		t.Error("Expected error on double-submit")
	}
}

func TestResolveNightActions_WolfKillsTarget(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find a villager to be the wolf target
	var targetID string
	for _, p := range g.Players {
		if p.Role == RoleVillager {
			targetID = p.ID
			break
		}
	}

	// Set wolf target directly
	g.NightActions.WolfTarget = &targetID
	g = ResolveNightActions(g)

	// Target should be dead
	for _, p := range g.Players {
		if p.ID == targetID {
			if p.IsAlive {
				t.Error("Wolf target should be dead after night resolve")
			}
			return
		}
	}
}

func TestResolveNightActions_DoctorSavesTarget(t *testing.T) {
	players := make([]PlayerInfo, 8)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player"}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g = StartNightPhase(g)

	// Find a villager to be both wolf target and doctor protect
	var targetID string
	for _, p := range g.Players {
		if p.Role == RoleVillager {
			targetID = p.ID
			break
		}
	}

	g.NightActions.WolfTarget = &targetID
	g.NightActions.DoctorTarget = &targetID // Doctor protects same person
	g = ResolveNightActions(g)

	// Target should still be alive (doctor saved)
	for _, p := range g.Players {
		if p.ID == targetID {
			if !p.IsAlive {
				t.Error("Doctor-protected target should survive")
			}
			return
		}
	}
}
