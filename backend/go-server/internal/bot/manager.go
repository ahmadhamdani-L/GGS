package bot

import (
	"fmt"
	"math/rand"

	"github.com/ggs/werewolf-server/internal/game"
)

// FillWithBots adds bots to reach minimum player count (8).
// Legacy function for backward compatibility.
func FillWithBots(playerNames []string, playerIDs []string, targetCount int) ([]string, []string) {
	botsNeeded := targetCount - len(playerNames)
	if botsNeeded <= 0 {
		return playerNames, playerIDs
	}

	available := make([]string, len(BotNames))
	copy(available, BotNames)
	rand.Shuffle(len(available), func(i, j int) { available[i], available[j] = available[j], available[i] })

	for i := 0; i < botsNeeded && i < len(available); i++ {
		botID := fmt.Sprintf("bot-%d", i+1)
		botName := available[i]
		playerNames = append(playerNames, botName)
		playerIDs = append(playerIDs, botID)
	}

	return playerNames, playerIDs
}

// FillWithBotsInfo adds bots to reach target player count using PlayerInfo struct.
// Bots get randomized names and default chibi configs.
func FillWithBotsInfo(playerInfos []game.PlayerInfo, targetCount int) []game.PlayerInfo {
	botsNeeded := targetCount - len(playerInfos)
	if botsNeeded <= 0 {
		return playerInfos
	}

	available := make([]string, len(BotNames))
	copy(available, BotNames)
	rand.Shuffle(len(available), func(i, j int) { available[i], available[j] = available[j], available[i] })

	for i := 0; i < botsNeeded && i < len(available); i++ {
		botID := fmt.Sprintf("bot-%d", i+1)
		botName := available[i]
		
		// Create bot with random chibi config
		playerInfos = append(playerInfos, game.PlayerInfo{
			ID:          botID,
			DisplayName: botName,
			AvatarID:    (i % 4) + 1, // Cycle through avatars 1-4
			ChibiConfig: generateBotChibiConfig(i),
		})
	}

	return playerInfos
}

// generateBotChibiConfig creates a randomized chibi config for bots
func generateBotChibiConfig(seed int) map[string]interface{} {
	// Predefined skin tones
	skinTones := []int{0xFFFFDBB4, 0xFFEDB183, 0xFFC68642, 0xFF8D5524, 0xFFFFE0BD}
	// Predefined hair colors
	hairColors := []int{0xFF4A3728, 0xFF1C1C1C, 0xFFD4A574, 0xFFB87333, 0xFF654321, 0xFF2E1A47}
	// Predefined shirt colors  
	shirtColors := []int{0xFF2196F3, 0xFF4CAF50, 0xFFF44336, 0xFF9C27B0, 0xFFFF9800, 0xFF607D8B}
	// Predefined pants colors
	pantsColors := []int{0xFF37474F, 0xFF1976D2, 0xFF455A64, 0xFF5D4037, 0xFF424242}
	
	return map[string]interface{}{
		"skinColor":      skinTones[seed%len(skinTones)],
		"hairColor":      hairColors[seed%len(hairColors)],
		"eyeColor":       0xFF5D4037, // Brown eyes
		"shirtColor":     shirtColors[seed%len(shirtColors)],
		"pantsColor":     pantsColors[seed%len(pantsColors)],
		"hairStyle":      seed % 6,
		"eyeStyle":       seed % 3,
		"expression":     2, // Smile
		"shirtStyle":     seed % 4,
		"accessory":      0, // No accessory
		"accessoryColor": nil,
		"showBlush":      seed%2 == 0,
		"version":        1,
	}
}

// MarkBots sets IsBot flag on players that have bot IDs
func MarkBots(state *game.GameState) {
	for i := range state.Players {
		if len(state.Players[i].ID) >= 4 && state.Players[i].ID[:4] == "bot-" {
			state.Players[i].IsBot = true
		}
	}
}

// ProcessBotActions handles all bot actions for the current phase.
func ProcessBotActions(state *game.GameState, diff Difficulty) *game.GameState {
	if state == nil {
		return nil
	}
	switch state.Phase {
	case game.PhaseNight:
		return processBotNightSequential(state, diff)
	case game.PhaseVoting:
		doBotVotes(state, diff)
		return state
	case game.PhaseRoleReveal:
		return processBotRoleConfirm(state)
	}
	return state
}

// processBotNightSequential handles bots acting during night.
// All bots submit their actions immediately. If all humans also done, resolve.
func processBotNightSequential(state *game.GameState, diff Difficulty) *game.GameState {
	if state.Phase != game.PhaseNight {
		return state
	}

	if state.NightActions.SubmittedPlayers == nil {
		state.NightActions.SubmittedPlayers = make(map[string]bool)
	}
	if state.NightActions.WolfVotes == nil {
		state.NightActions.WolfVotes = make(map[string]string)
	}

	for _, p := range state.Players {
		if !p.IsBot || !p.IsAlive || state.NightActions.SubmittedPlayers[p.ID] {
			continue
		}
		switch p.Role {
		case game.RoleWerewolf:
			target := DecideNightAction(state, p.ID, diff)
			if target != "" { state.NightActions.WolfVotes[p.ID] = target }
			state.NightActions.SubmittedPlayers[p.ID] = true
		case game.RoleSeer:
			target := DecideNightAction(state, p.ID, diff)
			if target != "" {
				tp := findPlayerByID(state, target)
				if tp != nil {
					team := string(game.GetRoleTeam(tp.Role))
					if state.NightActions.SeerTarget == nil { 
						state.NightActions.SeerTarget = &target
						state.NightActions.SeerResult = &team
						state.NightActions.SeerSubmitterId = &p.ID
					} else if state.NightActions.Seer2Target == nil {
						state.NightActions.Seer2Target = &target
						state.NightActions.Seer2Result = &team
						state.NightActions.Seer2SubmitterId = &p.ID
					}
				}
			}
			state.NightActions.SubmittedPlayers[p.ID] = true
		case game.RoleDoctor:
			target := DecideNightAction(state, p.ID, diff)
			if target != "" { state.NightActions.DoctorTarget = &target }
			state.NightActions.SubmittedPlayers[p.ID] = true
		case game.RoleWitch:
			useHeal, poisonTarget := DecideWitchAction(state, p.ID, diff)
			state.NightActions.WitchAction = &game.WitchAction{UseHeal: useHeal, PoisonTarget: poisonTarget}
			if useHeal { state.WitchHealUsed = true }
			if poisonTarget != nil { state.WitchPoisonUsed = true }
			state.NightActions.SubmittedPlayers[p.ID] = true
		default:
			state.NightActions.SubmittedPlayers[p.ID] = true
		}
	}

	// Check if ALL non-villager connected humans have submitted → resolve.
	// H-1 FIX: disconnected players are excluded from the wait check.
	allHumansDone := true
	for _, p := range state.Players {
		if !p.IsBot && p.IsAlive && p.IsConnected && p.Role != game.RoleVillager {
			if !state.NightActions.SubmittedPlayers[p.ID] {
				allHumansDone = false
				break
			}
		}
	}
	// Also check if there are NO connected human special roles (all bots or all disconnected)
	hasConnectedHumanSpecial := false
	for _, p := range state.Players {
		if !p.IsBot && p.IsAlive && p.IsConnected && p.Role != game.RoleVillager {
			hasConnectedHumanSpecial = true
			break
		}
	}

	if allHumansDone || !hasConnectedHumanSpecial {
		// Resolve wolf consensus
		if len(state.NightActions.WolfVotes) > 0 {
			targetCounts := make(map[string]int)
			for _, tid := range state.NightActions.WolfVotes { targetCounts[tid]++ }
			maxCount := 0; var wt string
			for tid, c := range targetCounts { if c > maxCount { maxCount = c; wt = tid } }
			state.NightActions.WolfTarget = &wt
		}
		state = game.ResolveNightActions(state)
	}

	return state
}

// processBotRoleConfirm marks all bots as having confirmed their roles.
// C-3 FIX: Was using ProtectedThisNight (doctor's field) instead of HasConfirmedRole.
// This caused bot role confirmation to never register, making ConfirmRoleReveal
// wait forever (until timer) even when only bots were unconfirmed.
func processBotRoleConfirm(state *game.GameState) *game.GameState {
	for i := range state.Players {
		if state.Players[i].IsBot {
			state.Players[i].HasConfirmedRole = true
		}
	}
	return state
}

func doBotVotes(state *game.GameState, diff Difficulty) {
	// Bots only vote if human players have already voted OR if > 50% of voting time has passed.
	// For now, bots vote immediately BUT we don't auto-resolve here — let the timer or human votes trigger resolution.
	for _, p := range state.Players {
		if p.IsBot && p.IsAlive {
			if _, voted := state.Votes.Votes[p.ID]; !voted {
				target := DecideVote(state, p.ID, diff)
				if target != "" {
					state.Votes.Votes[p.ID] = target
				}
			}
		}
	}
	// NOTE: Do NOT call resolveVotes here!
	// Let the game engine's CastVote (when human votes) or timer auto-resolve handle it.
}

func aliveNonTeam(state *game.GameState, team game.Team) []string {
	var result []string
	for _, p := range state.Players {
		if p.IsAlive && game.GetRoleTeam(p.Role) != team {
			result = append(result, p.ID)
		}
	}
	return result
}
