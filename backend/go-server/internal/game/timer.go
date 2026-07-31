package game

import "time"

// SetTimerDeadline sets the timer deadline on the game state based on the current phase.
// Returns the updated state with TimerDeadline set.
func SetTimerDeadline(state *GameState) *GameState {
	var durationSec int

	switch state.Phase {
	case PhaseRoleReveal:
		durationSec = 15
	case PhaseNight:
		durationSec = state.Config.TimerDuration.NightAction
	case PhaseWolfTurn, PhaseDoctorTurn, PhaseWitchTurn, PhaseSeerTurn:
		durationSec = state.Config.TimerDuration.NightAction
	case PhaseDiscussion:
		durationSec = state.Config.TimerDuration.Discussion
	case PhaseVoting:
		durationSec = state.Config.TimerDuration.Voting
	case PhaseTestament:
		durationSec = state.Config.TimerDuration.Testament
	case PhaseDayStart:
		durationSec = 5
	default:
		state.TimerDeadline = nil
		return state
	}

	deadline := time.Now().UnixMilli() + int64(durationSec*1000)
	state.TimerDeadline = &deadline
	return state
}

// AutoAdvanceOnTimeout handles what happens when a phase timer expires.
// Returns the updated game state after auto-skip/advance.
func AutoAdvanceOnTimeout(state *GameState) *GameState {
	switch state.Phase {
	case PhaseRoleReveal:
		// Auto-confirm all players
		for i := range state.Players {
			state.Players[i].ProtectedThisNight = false
		}
		state = StartNightPhase(state)

	case PhaseNight:
		// Night timer expired — resolve with whatever actions submitted
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

	case PhaseWolfTurn, PhaseDoctorTurn, PhaseWitchTurn, PhaseSeerTurn:
		// Legacy phases — just resolve night
		state = ResolveNightActions(state)

	case PhaseDayStart:
		// Advance to discussion
		state.Phase = PhaseDiscussion
		state = SetTimerDeadline(state)

	case PhaseDiscussion:
		// Move to voting
		state.Phase = PhaseVoting
		state.Votes = VoteRecord{Votes: make(map[string]string), Round: state.Round}
		state = SetTimerDeadline(state)

	case PhaseVoting:
		// Resolve with current votes (even if not all voted)
		if len(state.Votes.Votes) > 0 {
			state = resolveVotes(state)
		} else {
			// No votes — skip elimination, go to night
			state.Round++
			state.Votes = VoteRecord{Votes: make(map[string]string), Round: state.Round}
			state = StartNightPhase(state)
		}

	case PhaseTestament:
		// Time's up for testament
		state.PendingTestamentPlayerID = nil
		winner := checkWinCondition(state)
		if winner != nil {
			state.Winner = winner
			state.Phase = PhaseGameEnd
		} else {
			state.Round++
			state.Votes = VoteRecord{Votes: make(map[string]string), Round: state.Round}
			state = StartNightPhase(state)
		}
	}

	return state
}
