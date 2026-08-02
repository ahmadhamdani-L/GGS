package game

// FilterStateForPlayer returns a copy of GameState with roles hidden based on
// what the requesting player is allowed to see.
// Rules:
//   - Werewolves see other werewolves' roles
//   - Witch sees all werewolf roles (WW don't know who Witch is)
//   - Seers see other seers' roles
//   - Doctor/Villager see no other roles
//   - Dead players (in GAME_END/RESULTS) see all roles
//   - Wolf target is visible to Witch during WITCH_TURN
func FilterStateForPlayer(state *GameState, playerID string) *GameState {
	// Find the requesting player
	var me *PlayerState
	for i := range state.Players {
		if state.Players[i].ID == playerID {
			me = &state.Players[i]
			break
		}
	}

	// If game is over, reveal everything
	if state.Phase == PhaseGameEnd || state.Phase == PhaseResults {
		return state
	}

	// Create a copy of the game state with filtered players
	filtered := *state
	filteredPlayers := make([]PlayerState, len(state.Players))
	copy(filteredPlayers, state.Players)

	for i := range filteredPlayers {
		if filteredPlayers[i].ID == playerID {
			// Player always sees their own role
			continue
		}

		canSeeRole := false

		// Dead players' roles are always revealed to everyone
		if !filteredPlayers[i].IsAlive {
			canSeeRole = true
		}

		if !canSeeRole && me != nil {
			switch me.Role {
			case RoleWerewolf:
				// Werewolves see other werewolves
				if filteredPlayers[i].Role == RoleWerewolf {
					canSeeRole = true
				}
			case RoleWitch:
				// Witch sees all werewolves
				if filteredPlayers[i].Role == RoleWerewolf {
					canSeeRole = true
				}
			case RoleSeer:
				// Seers see other seers
				if filteredPlayers[i].Role == RoleSeer {
					canSeeRole = true
				}
			}
		}

		if !canSeeRole {
			filteredPlayers[i].Role = "" // Hide role
		}
	}

	filtered.Players = filteredPlayers

	// Populate teammates list for night phase visibility
	if me != nil {
		var teammates []TeammateInfo
		switch me.Role {
		case RoleWerewolf:
			// Werewolves see all other werewolves
			for _, p := range state.Players {
				if p.ID != playerID && p.Role == RoleWerewolf && p.IsAlive {
					teammates = append(teammates, TeammateInfo{ID: p.ID, Name: p.Name, Role: string(RoleWerewolf)})
				}
			}
		case RoleSeer:
			// Seers see other seers
			for _, p := range state.Players {
				if p.ID != playerID && p.Role == RoleSeer && p.IsAlive {
					teammates = append(teammates, TeammateInfo{ID: p.ID, Name: p.Name, Role: string(RoleSeer)})
				}
			}
		case RoleWitch:
			// Witch sees all werewolves (but they don't see her)
			for _, p := range state.Players {
				if p.Role == RoleWerewolf && p.IsAlive {
					teammates = append(teammates, TeammateInfo{ID: p.ID, Name: p.Name, Role: string(RoleWerewolf)})
				}
			}
		}
		filtered.Teammates = teammates
	}

	// Filter night actions - only show what's relevant to this player
	filteredNA := NightActions{}
	if me != nil {
		switch me.Role {
		case RoleWerewolf:
			filteredNA.WolfTarget = state.NightActions.WolfTarget
			filteredNA.WolfVotes = state.NightActions.WolfVotes
		case RoleDoctor:
			filteredNA.DoctorTarget = state.NightActions.DoctorTarget
		case RoleWitch:
			// Witch can see wolf target (to decide heal) and her own action
			filteredNA.WolfTarget = state.NightActions.WolfTarget
			filteredNA.WitchAction = state.NightActions.WitchAction
		case RoleSeer:
			// Seer sees their own result only
			// Use SeerSubmitterId to determine which result belongs to this player
			if state.NightActions.SeerSubmitterId != nil && *state.NightActions.SeerSubmitterId == playerID {
				filteredNA.SeerTarget = state.NightActions.SeerTarget
				filteredNA.SeerResult = state.NightActions.SeerResult
			}
			if state.NightActions.Seer2SubmitterId != nil && *state.NightActions.Seer2SubmitterId == playerID {
				// Use Seer2 slot but send as SeerTarget/SeerResult for consistency in client
				filteredNA.SeerTarget = state.NightActions.Seer2Target
				filteredNA.SeerResult = state.NightActions.Seer2Result
			}
		}
	}
	filtered.NightActions = filteredNA

	return &filtered
}

// FilterStateForSpectator creates a view of the game for spectators.
// Shows: player names, alive/dead status, current phase, timer, votes (public).
// Hides: all roles (until game end), night actions, seer results, team info.
func FilterStateForSpectator(state *GameState) *GameState {
	if state == nil {
		return nil
	}

	// Copy players without role info (unless game ended)
	players := make([]PlayerState, len(state.Players))
	for i, p := range state.Players {
		players[i] = PlayerState{
			ID:          p.ID,
			Name:        p.Name,
			AvatarID:    p.AvatarID,
			ChibiConfig: p.ChibiConfig,
			IsAlive:     p.IsAlive,
			IsBot:       p.IsBot,
			IsConnected: p.IsConnected,
		}
		// Reveal roles only after game ends
		if state.Phase == PhaseGameEnd {
			players[i].Role = p.Role
		} else {
			players[i].Role = "" // hide role from spectators
		}
	}

	spectatorState := &GameState{
		ID:      state.ID,
		Phase:   state.Phase,
		Round:   state.Round,
		Config:  state.Config,
		Players: players,
		Votes:   state.Votes,  // votes are public
		Winner:  state.Winner,
		TimerDeadline: state.TimerDeadline,
		EliminationHistory: state.EliminationHistory,
		Testaments:         state.Testaments,
		// Hide: NightActions, Teammates, SeerResult, etc.
	}
	return spectatorState
}
