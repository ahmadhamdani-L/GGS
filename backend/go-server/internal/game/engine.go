package game

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"time"
)

// Default role compositions per player count
var defaultRoleCompositions = map[int]map[Role]int{
	8:  {RoleWerewolf: 2, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 2},
	9:  {RoleWerewolf: 2, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 3},
	10: {RoleWerewolf: 3, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 3},
	11: {RoleWerewolf: 3, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 4},
	12: {RoleWerewolf: 4, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 4},
	13: {RoleWerewolf: 4, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 5},
	14: {RoleWerewolf: 4, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 6},
	15: {RoleWerewolf: 4, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 7},
	16: {RoleWerewolf: 4, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 8},
	17: {RoleWerewolf: 5, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 8},
	18: {RoleWerewolf: 5, RoleSeer: 2, RoleDoctor: 1, RoleWitch: 1, RoleVillager: 9},
}

func generateGameID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func getDefaultRoleConfig(playerCount int) map[Role]int {
	if playerCount < 8 {
		playerCount = 8
	}
	if playerCount > 18 {
		playerCount = 18
	}
	config := defaultRoleCompositions[playerCount]
	result := make(map[Role]int)
	for k, v := range config {
		result[k] = v
	}
	return result
}

// distributeRoles shuffles and assigns roles
func distributeRoles(config map[Role]int, playerCount int) []Role {
	roles := make([]Role, 0, playerCount)
	for role, count := range config {
		for i := 0; i < count; i++ {
			roles = append(roles, role)
		}
	}

	// Fisher-Yates shuffle
	for i := len(roles) - 1; i > 0; i-- {
		j, _ := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
		roles[i], roles[j.Int64()] = roles[j.Int64()], roles[i]
	}
	return roles
}

// PlayerInfo is used when creating a game with full player data
type PlayerInfo struct {
	ID          string
	DisplayName string
	AvatarID    int
	ChibiConfig map[string]interface{}
}

// CreateGame creates a new game from player info
func CreateGame(playerInfos []PlayerInfo) *GameState {
	playerCount := len(playerInfos)
	roleConfig := getDefaultRoleConfig(playerCount)

	players := make([]PlayerState, playerCount)
	for i, info := range playerInfos {
		players[i] = PlayerState{
			ID:          info.ID,
			Name:        info.DisplayName,
			Avatar:      fmt.Sprintf("avatar-%d", info.AvatarID), // Legacy format
			AvatarID:    info.AvatarID,
			ChibiConfig: info.ChibiConfig,
			IsBot:       false,
			Role:        RoleVillager, // placeholder
			IsAlive:     true,
			IsConnected: true,
		}
	}

	hostID := ""
	if len(playerInfos) > 0 {
		hostID = playerInfos[0].ID
	}

	return &GameState{
		ID:    generateGameID(),
		Phase: PhaseLobby,
		Round: 0,
		Config: GameConfig{
			MinPlayers: 8,
			MaxPlayers: 18,
			Roles:      roleConfig,
			TimerDuration: TimerConfig{
				Discussion:  60,
				Voting:      30,
				NightAction: 30,
				Testament:   10,
			},
			Mode:          "online",
			FlexibleTimer: false,
			HostID:        hostID,
		},
		Players:            players,
		NightActions:       NightActions{},
		Votes:              VoteRecord{Votes: make(map[string]string)},
		EliminationHistory: []EliminationEvent{},
		Testaments:         []Testament{},
	}
}

// CreateGameLegacy creates a new game from player names (for backward compatibility)
func CreateGameLegacy(playerNames []string, playerIDs []string) *GameState {
	playerInfos := make([]PlayerInfo, len(playerIDs))
	for i := range playerIDs {
		name := playerIDs[i]
		if i < len(playerNames) {
			name = playerNames[i]
		}
		playerInfos[i] = PlayerInfo{
			ID:          playerIDs[i],
			DisplayName: name,
			AvatarID:    (i % 4) + 1, // Cycle through avatars 1-4
			ChibiConfig: nil,         // No chibi for legacy
		}
	}
	return CreateGame(playerInfos)
}

// StartGame transitions from LOBBY → ROLE_REVEAL
func StartGame(state *GameState) *GameState {
	roles := distributeRoles(state.Config.Roles, len(state.Players))
	for i := range state.Players {
		if i < len(roles) {
			state.Players[i].Role = roles[i]
		}
	}
	state.Phase = PhaseRoleReveal
	state.Round = 1
	state = SetTimerDeadline(state)
	return state
}

// ConfirmRoleReveal marks player as confirmed
func ConfirmRoleReveal(state *GameState, playerID string) *GameState {
	for i := range state.Players {
		if state.Players[i].ID == playerID {
			state.Players[i].ProtectedThisNight = true
			break
		}
	}

	// Check if all confirmed
	allConfirmed := true
	for _, p := range state.Players {
		if !p.ProtectedThisNight {
			allConfirmed = false
			break
		}
	}

	if allConfirmed {
		for i := range state.Players {
			state.Players[i].ProtectedThisNight = false
		}
		state = StartNightPhase(state)
	}
	return state
}

// advanceNightPhase progresses through night sub-phases
func advanceNightPhase(state *GameState) *GameState {
	aliveRoles := make(map[Role]bool)
	for _, p := range state.Players {
		if p.IsAlive {
			aliveRoles[p.Role] = true
		}
	}

	switch state.Phase {
	case PhaseNightStart:
		state.Phase = PhaseWolfTurn
		state.NightActions = NightActions{WolfVotes: make(map[string]string)}

	case PhaseWolfTurn:
		// Check doctor alive and has protects
		doctorCanAct := false
		for _, p := range state.Players {
			if p.Role == RoleDoctor && p.IsAlive && p.DoctorProtectsUsed < 3 {
				doctorCanAct = true
				break
			}
		}
		if doctorCanAct {
			state.Phase = PhaseDoctorTurn
		} else if aliveRoles[RoleWitch] && (!state.WitchHealUsed || !state.WitchPoisonUsed) {
			state.Phase = PhaseWitchTurn
		} else if aliveRoles[RoleSeer] {
			state.Phase = PhaseSeerTurn
		} else {
			state.Phase = PhaseNightResolve
		}

	case PhaseDoctorTurn:
		if aliveRoles[RoleWitch] && (!state.WitchHealUsed || !state.WitchPoisonUsed) {
			state.Phase = PhaseWitchTurn
		} else if aliveRoles[RoleSeer] {
			state.Phase = PhaseSeerTurn
		} else {
			state.Phase = PhaseNightResolve
		}

	case PhaseWitchTurn:
		if aliveRoles[RoleSeer] {
			state.Phase = PhaseSeerTurn
		} else {
			state.Phase = PhaseNightResolve
		}

	case PhaseSeerTurn:
		state.Phase = PhaseNightResolve
	}

	return state
}

// SubmitNightAction handles wolf, doctor, seer actions
func SubmitNightAction(state *GameState, playerID, targetID string) (*GameState, error) {
	player := findPlayer(state, playerID)
	if player == nil {
		return state, errors.New("player not found")
	}
	if !player.IsAlive {
		return state, errors.New("dead players cannot act")
	}

	target := findPlayer(state, targetID)
	if target == nil {
		return state, errors.New("target not found")
	}

	switch state.Phase {
	case PhaseWolfTurn:
		if player.Role != RoleWerewolf {
			return state, errors.New("only werewolves can act now")
		}
		if !target.IsAlive {
			return state, errors.New("target must be alive")
		}
		if target.Role == RoleWerewolf {
			return state, errors.New("cannot target fellow werewolf")
		}

		// Track individual wolf votes
		if state.NightActions.WolfVotes == nil {
			state.NightActions.WolfVotes = make(map[string]string)
		}
		state.NightActions.WolfVotes[playerID] = targetID

		// Count alive werewolves
		aliveWolves := 0
		for _, p := range state.Players {
			if p.Role == RoleWerewolf && p.IsAlive {
				aliveWolves++
			}
		}

		// Check if all wolves have voted
		if len(state.NightActions.WolfVotes) < aliveWolves {
			// Not all wolves voted yet — don't advance
			return state, nil
		}

		// Resolve wolf consensus: pick the target with most votes (tie = first found)
		targetCounts := make(map[string]int)
		for _, tid := range state.NightActions.WolfVotes {
			targetCounts[tid]++
		}
		maxCount := 0
		var consensusTarget string
		for tid, count := range targetCounts {
			if count > maxCount {
				maxCount = count
				consensusTarget = tid
			}
		}
		state.NightActions.WolfTarget = &consensusTarget

	case PhaseDoctorTurn:
		if player.Role != RoleDoctor {
			return state, errors.New("only doctor can act now")
		}
		if !target.IsAlive {
			return state, errors.New("target must be alive")
		}
		if state.LastDoctorTarget != nil && *state.LastDoctorTarget == targetID {
			return state, errors.New("cannot protect same player consecutively")
		}
		if player.DoctorProtectsUsed >= 3 {
			return state, errors.New("doctor has used all 3 protects")
		}
		state.NightActions.DoctorTarget = &targetID

	case PhaseSeerTurn:
		if player.Role != RoleSeer {
			return state, errors.New("only seer can act now")
		}
		if playerID == targetID {
			return state, errors.New("cannot check yourself")
		}
		if !target.IsAlive {
			return state, errors.New("target must be alive")
		}
		targetTeam := string(GetRoleTeam(target.Role))
		if state.NightActions.SeerTarget == nil {
			state.NightActions.SeerTarget = &targetID
			state.NightActions.SeerResult = &targetTeam
			state.NightActions.SeerSubmitterId = &playerID
		} else {
			state.NightActions.Seer2Target = &targetID
			state.NightActions.Seer2Result = &targetTeam
			state.NightActions.Seer2SubmitterId = &playerID
		}

	default:
		return state, fmt.Errorf("cannot perform night action in phase %s", state.Phase)
	}

	// Auto-advance after action
	state = advanceNightPhase(state)

	// If we reached NIGHT_RESOLVE, resolve night
	if state.Phase == PhaseNightResolve {
		state = resolveNight(state)
	}

	state = SetTimerDeadline(state)
	return state, nil
}

// SubmitWitchAction handles witch heal/poison
func SubmitWitchAction(state *GameState, playerID string, useHeal bool, poisonTarget *string) (*GameState, error) {
	if state.Phase != PhaseWitchTurn {
		return state, errors.New("witch can only act during WITCH_TURN")
	}

	player := findPlayer(state, playerID)
	if player == nil || player.Role != RoleWitch {
		return state, errors.New("only witch can act")
	}

	if useHeal && poisonTarget != nil {
		return state, errors.New("cannot use heal and poison same night")
	}

	if useHeal {
		if state.WitchHealUsed {
			return state, errors.New("heal already used")
		}
	}
	if poisonTarget != nil {
		if state.WitchPoisonUsed {
			return state, errors.New("poison already used")
		}
	}

	state.NightActions.WitchAction = &WitchAction{
		UseHeal:      useHeal,
		PoisonTarget: poisonTarget,
	}

	// Advance
	state = advanceNightPhase(state)
	if state.Phase == PhaseNightResolve {
		state = resolveNight(state)
	}

	state = SetTimerDeadline(state)
	return state, nil
}

// CastVote handles a player's vote
func CastVote(state *GameState, voterID, targetID string) (*GameState, error) {
	if state.Phase != PhaseVoting {
		return state, errors.New("voting only in VOTING phase")
	}

	voter := findPlayer(state, voterID)
	if voter == nil || !voter.IsAlive {
		return state, errors.New("voter must be alive player")
	}

	state.Votes.Votes[voterID] = targetID

	// Do NOT auto-resolve when all votes are in.
	// Resolution happens ONLY when the timer expires (AutoAdvanceOnTimeout).
	// This allows players to change their vote before the deadline.

	return state, nil
}

// SubmitTestament records a dying player's last words
func SubmitTestament(state *GameState, playerID, message string) *GameState {
	player := findPlayer(state, playerID)
	if player == nil {
		return state
	}

	// Truncate to 200 chars
	if len(message) > 200 {
		message = message[:200]
	}

	state.Testaments = append(state.Testaments, Testament{
		PlayerID:   playerID,
		PlayerName: player.Name,
		Message:    message,
		Round:      state.Round,
		Phase:      "day",
		Timestamp:  time.Now().UnixMilli(),
	})

	state.PendingTestamentPlayerID = nil

	// After testament, decide where to go based on context
	winner := checkWinCondition(state)
	if winner != nil {
		state.Winner = winner
		state.Phase = PhaseGameEnd
		return state
	}

	// Check if this was a night-kill testament (go to DAY_START) or day-vote testament (go to NIGHT)
	lastElim := state.EliminationHistory[len(state.EliminationHistory)-1]
	if lastElim.Phase == "night" {
		// Night kill testament → move to DAY_START
		state.Phase = PhaseDayStart
		state = SetTimerDeadline(state)
	} else {
		// Day vote testament → move to next night
		state.Round++
		state.Votes = VoteRecord{Votes: make(map[string]string), Round: state.Round}
		state = StartNightPhase(state)
	}
	return state
}

// resolveNight processes all night actions and determines deaths
func resolveNight(state *GameState) *GameState {
	na := state.NightActions
	var wolfKillID *string

	// 1. Wolf target
	if na.WolfTarget != nil {
		wolfKillID = na.WolfTarget
	}

	// 2. Doctor protect
	if na.DoctorTarget != nil && wolfKillID != nil && *na.DoctorTarget == *wolfKillID {
		wolfKillID = nil
	}

	// 3. Witch heal
	if na.WitchAction != nil && na.WitchAction.UseHeal && na.WolfTarget != nil {
		wolfKillID = nil
		state.WitchHealUsed = true
	}

	// 4. Apply wolf kill
	if wolfKillID != nil {
		for i := range state.Players {
			if state.Players[i].ID == *wolfKillID {
				state.Players[i].IsAlive = false
				state.EliminationHistory = append(state.EliminationHistory, EliminationEvent{
					PlayerID: *wolfKillID,
					Round:    state.Round,
					Phase:    "night",
					Role:     string(state.Players[i].Role),
				})
				break
			}
		}
	}

	// 5. Witch poison
	if na.WitchAction != nil && na.WitchAction.PoisonTarget != nil {
		poisonID := *na.WitchAction.PoisonTarget
		for i := range state.Players {
			if state.Players[i].ID == poisonID {
				state.Players[i].IsAlive = false
				state.EliminationHistory = append(state.EliminationHistory, EliminationEvent{
					PlayerID: poisonID,
					Round:    state.Round,
					Phase:    "night",
					Role:     string(state.Players[i].Role),
				})
				break
			}
		}
		state.WitchPoisonUsed = true
	}

	// 6. Update doctor protect tracking
	if na.DoctorTarget != nil {
		state.LastDoctorTarget = na.DoctorTarget
		for i := range state.Players {
			if state.Players[i].Role == RoleDoctor {
				state.Players[i].DoctorProtectsUsed++
				break
			}
		}
	}

	// 7. Check win condition
	winner := checkWinCondition(state)
	if winner != nil {
		state.Winner = winner
		state.Phase = PhaseGameEnd
		return state
	}

	// If someone died at night, give them testament opportunity
	nightDeaths := []string{}
	for _, e := range state.EliminationHistory {
		if e.Round == state.Round && e.Phase == "night" {
			nightDeaths = append(nightDeaths, e.PlayerID)
		}
	}
	if len(nightDeaths) > 0 {
		// First dead player gets testament
		state.PendingTestamentPlayerID = &nightDeaths[0]
		state.Phase = PhaseTestament
		state = SetTimerDeadline(state)
		return state
	}

	// Move to DAY_START (death announcement phase) before discussion
	state.Phase = PhaseDayStart
	state = SetTimerDeadline(state)
	return state
}

// resolveVotes processes voting results
func resolveVotes(state *GameState) *GameState {
	// Count votes
	voteCounts := make(map[string]int)
	for _, targetID := range state.Votes.Votes {
		voteCounts[targetID]++
	}

	// Find max votes
	maxVotes := 0
	for _, count := range voteCounts {
		if count > maxVotes {
			maxVotes = count
		}
	}

	// Find players with max votes
	var topVoted []string
	for playerID, count := range voteCounts {
		if count == maxVotes {
			topVoted = append(topVoted, playerID)
		}
	}

	if len(topVoted) == 1 {
		// Eliminate
		eliminatedID := topVoted[0]
		for i := range state.Players {
			if state.Players[i].ID == eliminatedID {
				state.Players[i].IsAlive = false
				state.EliminationHistory = append(state.EliminationHistory, EliminationEvent{
					PlayerID: eliminatedID,
					Round:    state.Round,
					Phase:    "day",
					Role:     string(state.Players[i].Role),
				})
				// Set up testament for eliminated player
				state.PendingTestamentPlayerID = &eliminatedID
				break
			}
		}

		// Check win condition
		winner := checkWinCondition(state)
		if winner != nil {
			state.Winner = winner
			state.Phase = PhaseGameEnd
			return state
		}

		// Go to testament phase for the eliminated player
		state.Phase = PhaseTestament
		state = SetTimerDeadline(state)
	} else {
		// Tie — retry or skip
		state.RetryVoteCount++
		if state.RetryVoteCount >= 2 {
			// Skip elimination, go to night
			state.Round++
			state.RetryVoteCount = 0
			state.Votes = VoteRecord{Votes: make(map[string]string), Round: state.Round}
			state = StartNightPhase(state)
		} else {
			state.Votes = VoteRecord{
				Votes:       make(map[string]string),
				Round:       state.Round,
				IsRetry:     true,
				TiedPlayers: topVoted,
			}
			state.Phase = PhaseVoting
			state = SetTimerDeadline(state)
		}
	}

	return state
}

// checkWinCondition checks if a team has won
func checkWinCondition(state *GameState) *Team {
	aliveWerewolves := 0
	aliveBlue := 0

	for _, p := range state.Players {
		if !p.IsAlive {
			continue
		}
		if p.Role == RoleWerewolf {
			aliveWerewolves++
		}
		if GetRoleTeam(p.Role) == TeamBlue {
			aliveBlue++
		}
	}

	if aliveWerewolves == 0 {
		team := TeamBlue
		return &team
	}
	if aliveWerewolves >= aliveBlue {
		team := TeamRed
		return &team
	}
	return nil
}

func findPlayer(state *GameState, id string) *PlayerState {
	for i := range state.Players {
		if state.Players[i].ID == id {
			return &state.Players[i]
		}
	}
	return nil
}
