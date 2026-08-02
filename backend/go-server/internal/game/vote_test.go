package game

import (
	"testing"
)

func makeTestGame(n int) *GameState {
	players := make([]PlayerInfo, n)
	for i := range players {
		players[i] = PlayerInfo{ID: "p" + string(rune('A'+i)), DisplayName: "Player" + string(rune('A'+i))}
	}
	g := CreateGame(players)
	g = StartGame(g)
	g.Phase = PhaseVoting
	g.Votes = VoteRecord{Votes: make(map[string]string)}
	for i := range g.Players {
		g.Players[i].IsConnected = true
	}
	return g
}

func TestResolveVotes_MajorityElimination(t *testing.T) {
	g := makeTestGame(8)
	// 5 players vote for player C
	target := g.Players[2].ID
	for i := 0; i < 5; i++ {
		if g.Players[i].ID == target {
			continue
		}
		g.Votes.Votes[g.Players[i].ID] = target
	}
	g = resolveVotes(g)

	// Player C should be dead
	for _, p := range g.Players {
		if p.ID == target {
			if p.IsAlive {
				t.Error("Expected target to be eliminated")
			}
			return
		}
	}
	t.Error("Target player not found")
}

func TestResolveVotes_Tie_TriggersRetry(t *testing.T) {
	g := makeTestGame(8)
	// 3 vote for A, 3 vote for B
	g.Votes.Votes[g.Players[2].ID] = g.Players[0].ID
	g.Votes.Votes[g.Players[3].ID] = g.Players[0].ID
	g.Votes.Votes[g.Players[4].ID] = g.Players[0].ID
	g.Votes.Votes[g.Players[5].ID] = g.Players[1].ID
	g.Votes.Votes[g.Players[6].ID] = g.Players[1].ID
	g.Votes.Votes[g.Players[7].ID] = g.Players[1].ID

	g = resolveVotes(g)

	// Should trigger retry vote (isRetry flag)
	if !g.Votes.IsRetry {
		t.Error("Expected tie to trigger retry vote")
	}
	if len(g.Votes.TiedPlayers) != 2 {
		t.Errorf("Expected 2 tied players, got %d", len(g.Votes.TiedPlayers))
	}
}

func TestResolveVotes_AllSkip_NoElimination(t *testing.T) {
	g := makeTestGame(8)
	// All alive players skip (empty vote)
	for _, p := range g.Players {
		if p.IsAlive {
			g.Votes.Votes[p.ID] = ""
		}
	}
	g = resolveVotes(g)

	// All should still be alive
	for _, p := range g.Players {
		if !p.IsAlive {
			t.Errorf("Player %s should still be alive after all-skip", p.ID)
		}
	}
}

func TestCastVote_AutoResolve_WhenAllVoted(t *testing.T) {
	g := makeTestGame(8)
	target := g.Players[7].ID

	// All alive players vote (triggers auto-resolve)
	for _, p := range g.Players {
		if p.IsAlive && p.ID != target {
			var err error
			g, err = CastVote(g, p.ID, target)
			if err != nil {
				t.Fatalf("CastVote failed: %v", err)
			}
		}
	}
	// Last voter
	g, _ = CastVote(g, target, g.Players[0].ID)

	// Should have auto-resolved (phase advanced)
	if g.Phase == PhaseVoting {
		t.Error("Expected phase to advance after all voted")
	}
}

func TestCheckWinCondition_AllWolvesDead_BlueWins(t *testing.T) {
	g := makeTestGame(8)
	// Kill all werewolves
	for i := range g.Players {
		if g.Players[i].Role == RoleWerewolf {
			g.Players[i].IsAlive = false
		}
	}
	winner := checkWinCondition(g)
	if winner == nil {
		t.Fatal("Expected a winner")
	}
	if *winner != TeamBlue {
		t.Errorf("Expected Blue team win, got %s", *winner)
	}
}

func TestCheckWinCondition_WolvesEqualBlue_RedWins(t *testing.T) {
	g := makeTestGame(8)
	// Kill blue team until wolves >= blue alive
	blueKilled := 0
	for i := range g.Players {
		if GetRoleTeam(g.Players[i].Role) == TeamBlue && blueKilled < 4 {
			g.Players[i].IsAlive = false
			blueKilled++
		}
	}
	winner := checkWinCondition(g)
	if winner == nil {
		t.Fatal("Expected a winner")
	}
	if *winner != TeamRed {
		t.Errorf("Expected Red team win, got %s", *winner)
	}
}
