package bot

import (
	"math/rand"

	"github.com/ggs/werewolf-server/internal/game"
)

// L-01 FIX: Removed deprecated rand.Seed(time.Now().UnixNano()) init().
// Since Go 1.20, the global rand is automatically seeded with a random value.
// Explicit seeding with time.Now().UnixNano() is a no-op and logs a deprecation warning.

// BotNames are default display names for bots
var BotNames = []string{
	"Luna", "Shadow", "Raven", "Storm", "Frost",
	"Blaze", "Ember", "Onyx", "Sage", "Ivy",
	"Atlas", "Nova", "Echo", "Viper", "Hawk",
}

// Difficulty levels affect decision quality
type Difficulty int

const (
	Easy   Difficulty = 0
	Medium Difficulty = 1
	Hard   Difficulty = 2
)

// DecideNightAction returns the target ID for a bot's night action
func DecideNightAction(state *game.GameState, botID string, difficulty Difficulty) string {
	bot := findBot(state, botID)
	if bot == nil {
		return ""
	}

	switch bot.Role {
	case game.RoleWerewolf:
		return wolfStrategy(state, bot, difficulty)
	case game.RoleDoctor:
		return doctorStrategy(state, bot, difficulty)
	case game.RoleSeer:
		return seerStrategy(state, bot, difficulty)
	default:
		return ""
	}
}

// DecideWitchAction returns witch's heal/poison decision
func DecideWitchAction(state *game.GameState, botID string, difficulty Difficulty) (useHeal bool, poisonTarget *string) {
	// Heal if wolf target exists and heal not used
	if !state.WitchHealUsed && state.NightActions.WolfTarget != nil {
		// Hard bots always heal, medium 70%, easy 50%
		healChance := 0.5
		if difficulty == Medium {
			healChance = 0.7
		}
		if difficulty == Hard {
			healChance = 0.95
		}
		if rand.Float64() < healChance {
			return true, nil
		}
	}

	// Poison: hard bots target suspicious players, others random or skip
	if !state.WitchPoisonUsed && difficulty >= Medium {
		// 30% chance to use poison
		if rand.Float64() < 0.3 {
			targets := aliveNonTeammates(state, botID, game.TeamRed)
			if len(targets) > 0 {
				t := targets[rand.Intn(len(targets))]
				return false, &t
			}
		}
	}

	return false, nil
}

// DecideVote returns who the bot votes for
func DecideVote(state *game.GameState, botID string, difficulty Difficulty) string {
	bot := findBot(state, botID)
	if bot == nil {
		return ""
	}

	switch bot.Role {
	case game.RoleWerewolf:
		return wolfVoteStrategy(state, bot, difficulty)
	default:
		return villagerVoteStrategy(state, bot, difficulty)
	}
}

// --- Strategies ---

func wolfStrategy(state *game.GameState, bot *game.PlayerState, diff Difficulty) string {
	// Target priority: Seer > Doctor > Villager
	targets := aliveNonTeammates(state, bot.ID, game.TeamRed)
	if len(targets) == 0 {
		return ""
	}

	if diff >= Medium {
		// Try to target seers/doctors first
		for _, tid := range targets {
			p := findPlayerByID(state, tid)
			if p != nil && (p.Role == game.RoleSeer || p.Role == game.RoleDoctor) {
				// Hard bot knows roles (simulates deduction), medium has 40% chance
				if diff == Hard || rand.Float64() < 0.4 {
					return tid
				}
			}
		}
	}

	return targets[rand.Intn(len(targets))]
}

func doctorStrategy(state *game.GameState, bot *game.PlayerState, diff Difficulty) string {
	alive := aliveOthers(state, bot.ID)
	if len(alive) == 0 {
		return bot.ID // protect self as last resort
	}

	if diff >= Hard {
		// Protect players who seem important (seers if known)
		// For now, randomize among non-wolves (bot doesn't know roles for sure)
	}

	// Random protection, can also protect self
	allTargets := append(alive, bot.ID)
	return allTargets[rand.Intn(len(allTargets))]
}

func seerStrategy(state *game.GameState, bot *game.PlayerState, diff Difficulty) string {
	// Check players we haven't checked yet (simplified: random alive player)
	alive := aliveOthers(state, bot.ID)
	if len(alive) == 0 {
		return ""
	}
	return alive[rand.Intn(len(alive))]
}

func wolfVoteStrategy(state *game.GameState, bot *game.PlayerState, diff Difficulty) string {
	// Wolves vote for non-wolf players, avoid voting for teammates
	targets := aliveNonTeammates(state, bot.ID, game.TeamRed)
	if len(targets) == 0 {
		// Fallback: vote for any alive player that isn't self
		others := aliveOthers(state, bot.ID)
		if len(others) == 0 {
			return ""
		}
		return others[rand.Intn(len(others))]
	}
	return targets[rand.Intn(len(targets))]
}

func villagerVoteStrategy(state *game.GameState, bot *game.PlayerState, diff Difficulty) string {
	others := aliveOthers(state, bot.ID)
	if len(others) == 0 {
		return ""
	}

	if diff >= Hard {
		// Try to vote for werewolves (simulates good deduction)
		for _, id := range others {
			p := findPlayerByID(state, id)
			if p != nil && p.Role == game.RoleWerewolf {
				if rand.Float64() < 0.6 { // 60% accuracy
					return id
				}
			}
		}
	}

	return others[rand.Intn(len(others))]
}

// --- Helpers ---

func findBot(state *game.GameState, id string) *game.PlayerState {
	for i := range state.Players {
		if state.Players[i].ID == id {
			return &state.Players[i]
		}
	}
	return nil
}

func findPlayerByID(state *game.GameState, id string) *game.PlayerState {
	for i := range state.Players {
		if state.Players[i].ID == id {
			return &state.Players[i]
		}
	}
	return nil
}

func aliveOthers(state *game.GameState, excludeID string) []string {
	var result []string
	for _, p := range state.Players {
		if p.IsAlive && p.ID != excludeID {
			result = append(result, p.ID)
		}
	}
	return result
}

func aliveNonTeammates(state *game.GameState, botID string, botTeam game.Team) []string {
	var result []string
	for _, p := range state.Players {
		if p.IsAlive && p.ID != botID && game.GetRoleTeam(p.Role) != botTeam {
			result = append(result, p.ID)
		}
	}
	return result
}
