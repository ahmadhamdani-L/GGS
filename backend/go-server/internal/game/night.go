package game

import "errors"

// StartNightPhase begins the night with sequential role turns.
// Order: Werewolf → Seer → Doctor → Witch
func StartNightPhase(state *GameState) *GameState {
	state.Phase = PhaseNight
	state.NightActions = NightActions{
		WolfVotes:        make(map[string]string),
		SubmittedPlayers: make(map[string]bool),
	}
	// Determine the current sub-turn based on who is alive
	state.NightActions.CurrentTurn = "werewolf"
	state = SetTimerDeadline(state)
	return state
}

// SubmitNightActionSequential handles a player's night action.
// Players can submit anytime during night; server resolves when all done or timer expires.
func SubmitNightActionSequential(state *GameState, playerID, targetID string, witchHeal bool, poisonTarget *string) (*GameState, error) {
	if state.Phase != PhaseNight {
		return state, errors.New("not night phase")
	}

	player := findPlayer(state, playerID)
	if player == nil || !player.IsAlive {
		return state, errors.New("player not found or dead")
	}

	// Already submitted?
	if state.NightActions.SubmittedPlayers[playerID] {
		return state, errors.New("already submitted")
	}

	switch player.Role {
	case RoleWerewolf:
		if targetID == "" {
			return state, errors.New("must select target")
		}
		target := findPlayer(state, targetID)
		if target == nil || !target.IsAlive || target.Role == RoleWerewolf {
			return state, errors.New("invalid target")
		}
		state.NightActions.WolfVotes[playerID] = targetID
		state.NightActions.SubmittedPlayers[playerID] = true

	case RoleSeer:
		if targetID != "" && targetID != playerID {
			target := findPlayer(state, targetID)
			if target != nil && target.IsAlive {
				team := string(GetRoleTeam(target.Role))
				if state.NightActions.SeerTarget == nil {
					state.NightActions.SeerTarget = &targetID
					state.NightActions.SeerResult = &team
					state.NightActions.SeerSubmitterId = &playerID
				} else {
					state.NightActions.Seer2Target = &targetID
					state.NightActions.Seer2Result = &team
					state.NightActions.Seer2SubmitterId = &playerID
				}
			}
		}
		state.NightActions.SubmittedPlayers[playerID] = true

	case RoleDoctor:
		if player.DoctorProtectsUsed >= 3 {
			return state, errors.New("no protects remaining")
		}
		if targetID != "" {
			if state.LastDoctorTarget != nil && *state.LastDoctorTarget == targetID {
				return state, errors.New("cannot protect same player consecutively")
			}
			state.NightActions.DoctorTarget = &targetID
		}
		state.NightActions.SubmittedPlayers[playerID] = true

	case RoleWitch:
		state.NightActions.WitchAction = &WitchAction{
			UseHeal:      witchHeal,
			PoisonTarget: poisonTarget,
		}
		state.NightActions.SubmittedPlayers[playerID] = true

	default:
		// Villagers just mark done
		state.NightActions.SubmittedPlayers[playerID] = true
	}

	// Check if ALL role-players (human, alive, connected) have submitted → resolve immediately.
	// H-1 FIX: Skip disconnected players — they will be auto-handled by the timer/disconnect
	// system. Waiting for a disconnected player blocks the entire game unnecessarily.
	allHumansDone := true
	for _, p := range state.Players {
		if !p.IsBot && p.IsAlive && p.IsConnected && p.Role != RoleVillager {
			if !state.NightActions.SubmittedPlayers[p.ID] {
				allHumansDone = false
				break
			}
		}
	}

	if allHumansDone {
		// Also resolve wolf consensus
		if len(state.NightActions.WolfVotes) > 0 {
			targetCounts := make(map[string]int)
			for _, tid := range state.NightActions.WolfVotes {
				targetCounts[tid]++
			}
			maxCount := 0
			var wolfTarget string
			for tid, count := range targetCounts {
				if count > maxCount {
					maxCount = count
					wolfTarget = tid
				}
			}
			state.NightActions.WolfTarget = &wolfTarget
		}
		state = ResolveNightActions(state)
	}

	return state, nil
}

// AdvanceNightTurn moves to the next role's turn (exported for bot use)
func AdvanceNightTurn(state *GameState) *GameState {
	return advanceNightTurn(state)
}

// advanceNightTurn moves to the next role's turn in order: WW → Seer → Doctor → Witch → Resolve
func advanceNightTurn(state *GameState) *GameState {
	current := state.NightActions.CurrentTurn

	// Determine next turn
	order := []string{"werewolf", "seer", "doctor", "witch"}
	nextIdx := 0
	for i, o := range order {
		if o == current {
			nextIdx = i + 1
			break
		}
	}

	// Find next role that has alive players
	for nextIdx < len(order) {
		role := order[nextIdx]
		if hasAliveRoleForTurn(state, role) {
			state.NightActions.CurrentTurn = role
			state = SetTimerDeadline(state)
			return state
		}
		nextIdx++
	}

	// All turns done — resolve night
	state = ResolveNightActions(state)
	return state
}

// hasAliveRoleForTurn checks if there are alive players for this role turn
func hasAliveRoleForTurn(state *GameState, turn string) bool {
	switch turn {
	case "werewolf":
		for _, p := range state.Players {
			if p.Role == RoleWerewolf && p.IsAlive {
				return true
			}
		}
	case "seer":
		for _, p := range state.Players {
			if p.Role == RoleSeer && p.IsAlive {
				return true
			}
		}
	case "doctor":
		for _, p := range state.Players {
			if p.Role == RoleDoctor && p.IsAlive && p.DoctorProtectsUsed < 3 {
				return true
			}
		}
	case "witch":
		for _, p := range state.Players {
			if p.Role == RoleWitch && p.IsAlive && (!state.WitchHealUsed || !state.WitchPoisonUsed) {
				return true
			}
		}
	}
	return false
}

// AllNightActionsSubmitted is kept for backward compatibility with timer.
func AllNightActionsSubmitted(state *GameState) bool {
	// In sequential mode, check if current turn's players are done
	return false // Timer handles timeout
}

// ResolveNightActions resolves all night actions and transitions to DAY_START.
func ResolveNightActions(state *GameState) *GameState {
	na := state.NightActions

	// Wolf kill
	var wolfKillID *string
	if na.WolfTarget != nil {
		wolfKillID = na.WolfTarget
	}

	// Doctor protect
	if na.DoctorTarget != nil && wolfKillID != nil && *na.DoctorTarget == *wolfKillID {
		wolfKillID = nil
	}

	// Witch heal
	if na.WitchAction != nil && na.WitchAction.UseHeal && na.WolfTarget != nil {
		wolfKillID = nil
		state.WitchHealUsed = true
	}

	// Apply wolf kill
	if wolfKillID != nil {
		for i := range state.Players {
			if state.Players[i].ID == *wolfKillID {
				state.Players[i].IsAlive = false
				state.EliminationHistory = append(state.EliminationHistory, EliminationEvent{
					PlayerID: *wolfKillID, Round: state.Round, Phase: "night",
					Role: string(state.Players[i].Role),
				})
				break
			}
		}
	}

	// Witch poison
	if na.WitchAction != nil && na.WitchAction.PoisonTarget != nil {
		poisonID := *na.WitchAction.PoisonTarget
		for i := range state.Players {
			if state.Players[i].ID == poisonID && state.Players[i].IsAlive {
				state.Players[i].IsAlive = false
				state.EliminationHistory = append(state.EliminationHistory, EliminationEvent{
					PlayerID: poisonID, Round: state.Round, Phase: "night",
					Role: string(state.Players[i].Role),
				})
				break
			}
		}
		state.WitchPoisonUsed = true
	}

	// Update doctor tracking
	if na.DoctorTarget != nil {
		state.LastDoctorTarget = na.DoctorTarget
		for i := range state.Players {
			if state.Players[i].Role == RoleDoctor && state.Players[i].IsAlive {
				state.Players[i].DoctorProtectsUsed++
				break
			}
		}
	}

	// Win check
	winner := checkWinCondition(state)
	if winner != nil {
		state.Winner = winner
		state.Phase = PhaseGameEnd
		return state
	}

	// → DAY_START
	state.Phase = PhaseDayStart
	state = SetTimerDeadline(state)
	return state
}
