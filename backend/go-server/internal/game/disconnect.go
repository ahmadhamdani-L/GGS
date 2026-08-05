package game

// MarkPlayerDisconnected marks a player as disconnected.
// Disconnected players are auto-skipped during their turn by the timer system.
func MarkPlayerDisconnected(state *GameState, playerID string) *GameState {
	for i := range state.Players {
		if state.Players[i].ID == playerID {
			state.Players[i].IsConnected = false
			break
		}
	}
	return state
}

// MarkPlayerReconnected marks a player as connected again.
func MarkPlayerReconnected(state *GameState, playerID string) *GameState {
	for i := range state.Players {
		if state.Players[i].ID == playerID {
			state.Players[i].IsConnected = true
			break
		}
	}
	return state
}

// HandleDisconnectedPlayerAction checks if the current active player is disconnected
// and auto-skips their action. Called by the timer system.
// Returns true if a skip was performed.
func HandleDisconnectedPlayerAction(state *GameState) (*GameState, bool) {
	switch state.Phase {
	case PhaseWolfTurn:
		// Check if all alive wolves are disconnected
		allDisconnected := true
		for _, p := range state.Players {
			if p.Role == RoleWerewolf && p.IsAlive && p.IsConnected {
				allDisconnected = false
				break
			}
		}
		if allDisconnected {
			// Pick random target
			for _, p := range state.Players {
				if p.IsAlive && p.Role != RoleWerewolf {
					id := p.ID
					state.NightActions.WolfTarget = &id
					break
				}
			}
			return state, true
		}

	case PhaseDoctorTurn:
		for _, p := range state.Players {
			if p.Role == RoleDoctor && p.IsAlive && !p.IsConnected {
				// Doctor is disconnected — skip protect
				return state, true
			}
		}

	case PhaseWitchTurn:
		for _, p := range state.Players {
			if p.Role == RoleWitch && p.IsAlive && !p.IsConnected {
				// Witch disconnected — skip
				state.NightActions.WitchAction = &WitchAction{}
				return state, true
			}
		}

	case PhaseSeerTurn:
		for _, p := range state.Players {
			if p.Role == RoleSeer && p.IsAlive && !p.IsConnected {
				// Seer disconnected — skip scan
				return state, true
			}
		}

	case PhaseVoting:
		// Auto-vote for disconnected players (random alive target)
		changed := false
		for _, p := range state.Players {
			if p.IsAlive && !p.IsConnected {
				if _, voted := state.Votes.Votes[p.ID]; !voted {
					// Vote for random alive player
					for _, target := range state.Players {
						if target.IsAlive && target.ID != p.ID {
							state.Votes.Votes[p.ID] = target.ID
							changed = true
							break
						}
					}
				}
			}
		}
		if changed {
			return state, true
		}
	}

	return state, false
}

// CountDisconnectedPlayers returns how many alive players are disconnected.
func CountDisconnectedPlayers(state *GameState) int {
	count := 0
	for _, p := range state.Players {
		if p.IsAlive && !p.IsConnected {
			count++
		}
	}
	return count
}

// ShouldAbortGame returns true if too many players disconnected (>50% alive).
// Does NOT abort if at least 1 human is still connected (even if dead — let them spectate).
func ShouldAbortGame(state *GameState) bool {
	humanConnected := 0
	for _, p := range state.Players {
		if !p.IsBot && p.IsConnected {
			humanConnected++
		}
	}
	// If at least 1 human is still connected (alive or dead), don't abort.
	// Let the game finish naturally so they can watch the result.
	if humanConnected >= 1 {
		return false
	}
	// All humans disconnected — abort
	return true
}
