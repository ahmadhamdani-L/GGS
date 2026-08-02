package bot

import (
	"testing"

	"github.com/ggs/werewolf-server/internal/game"
)

func TestFillWithBotsInfo_FillsCorrectly(t *testing.T) {
	players := []game.PlayerInfo{
		{ID: "real-1", DisplayName: "Player1", AvatarID: 1},
		{ID: "real-2", DisplayName: "Player2", AvatarID: 2},
	}
	result := FillWithBotsInfo(players, 8)
	if len(result) != 8 {
		t.Errorf("Expected 8 players, got %d", len(result))
	}
	// First 2 should be the real players
	if result[0].ID != "real-1" {
		t.Error("First player should be real-1")
	}
	if result[1].ID != "real-2" {
		t.Error("Second player should be real-2")
	}
	// Rest should be bots
	for i := 2; i < 8; i++ {
		if result[i].DisplayName == "" {
			t.Errorf("Bot %d has empty name", i)
		}
	}
}

func TestFillWithBotsInfo_NoFillIfEnough(t *testing.T) {
	players := make([]game.PlayerInfo, 10)
	for i := range players {
		players[i] = game.PlayerInfo{ID: "p" + string(rune('0'+i)), DisplayName: "P" + string(rune('0'+i))}
	}
	result := FillWithBotsInfo(players, 8) // target < current
	if len(result) != 10 {
		t.Errorf("Should not reduce players, expected 10 got %d", len(result))
	}
}

func TestProcessBotActions_NilState(t *testing.T) {
	result := ProcessBotActions(nil, Medium)
	if result != nil {
		t.Error("Expected nil for nil input")
	}
}

func TestProcessBotActions_GameEnd(t *testing.T) {
	state := &game.GameState{
		Phase: game.PhaseGameEnd,
	}
	result := ProcessBotActions(state, Medium)
	if result.Phase != game.PhaseGameEnd {
		t.Error("Should not modify game at PhaseGameEnd")
	}
}

func TestBotNames_NotEmpty(t *testing.T) {
	if len(BotNames) == 0 {
		t.Error("BotNames should not be empty")
	}
	for i, name := range BotNames {
		if name == "" {
			t.Errorf("BotNames[%d] is empty", i)
		}
	}
}
