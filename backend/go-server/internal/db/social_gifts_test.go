package db

import (
	"testing"
)

func TestCheckGiftRateLimit_NoDatabase(t *testing.T) {
	// With DB == nil, rate limit should always pass
	DB = nil
	err := checkGiftRateLimit("user-123")
	if err != nil {
		t.Errorf("Expected no error with nil DB, got: %v", err)
	}
}

func TestNullStr(t *testing.T) {
	if nullStr("") != nil {
		t.Error("Expected nil for empty string")
	}
	if nullStr("hello") != "hello" {
		t.Error("Expected 'hello' for non-empty string")
	}
}

func TestBuildEventList_Gift(t *testing.T) {
	gift := &GiftCatalogItem{
		ID: "rose", Type: "gift", Rarity: "common", BroadcastType: "none",
	}
	events := buildEventList(gift, false)
	if events[0] != "GiftSent" {
		t.Errorf("Expected GiftSent, got %s", events[0])
	}
	if len(events) != 3 {
		t.Errorf("Expected 3 events, got %d", len(events))
	}
}

func TestBuildEventList_CurseLegendary(t *testing.T) {
	curse := &GiftCatalogItem{
		ID: "skull", Type: "curse", Rarity: "legendary", BroadcastType: "global",
	}
	events := buildEventList(curse, true)
	// Should contain: CurseSent, CharmUpdated, PopularityUpdated, LegendaryGiftSent, ComboTriggered, GlobalBroadcast
	found := map[string]bool{}
	for _, e := range events {
		found[e] = true
	}
	if !found["CurseSent"] {
		t.Error("Missing CurseSent")
	}
	if !found["LegendaryGiftSent"] {
		t.Error("Missing LegendaryGiftSent")
	}
	if !found["ComboTriggered"] {
		t.Error("Missing ComboTriggered")
	}
	if !found["GlobalBroadcast"] {
		t.Error("Missing GlobalBroadcast")
	}
}

func TestCalculateRankTier(t *testing.T) {
	tests := []struct {
		xp   int64
		want string
	}{
		{0, "bronze"},
		{100, "bronze"},
		{150, "silver"},
		{400, "gold"},
		{1000, "platinum"},
		{2500, "diamond"},
		{5000, "master"},
		{10000, "grandmaster"},
	}
	for _, tc := range tests {
		got := CalculateRankTier(tc.xp)
		if got != tc.want {
			t.Errorf("CalculateRankTier(%d) = %s, want %s", tc.xp, got, tc.want)
		}
	}
}
