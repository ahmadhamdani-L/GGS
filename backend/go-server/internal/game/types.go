package game

// Team represents red or blue team
type Team string

const (
	TeamRed  Team = "red"
	TeamBlue Team = "blue"
)

// Role represents a player's role
type Role string

const (
	RoleVillager Role = "villager"
	RoleWerewolf Role = "werewolf"
	RoleSeer     Role = "seer"
	RoleDoctor   Role = "doctor"
	RoleWitch    Role = "witch"
)

// GetRoleTeam returns the team for a role
func GetRoleTeam(role Role) Team {
	switch role {
	case RoleWerewolf, RoleWitch:
		return TeamRed
	default:
		return TeamBlue
	}
}

// GamePhase represents game phases
type GamePhase string

const (
	PhaseLobby        GamePhase = "LOBBY"
	PhaseRoleReveal   GamePhase = "ROLE_REVEAL"
	PhaseNight        GamePhase = "NIGHT"         // All roles act simultaneously
	PhaseNightStart   GamePhase = "NIGHT_START"   // Legacy (unused now)
	PhaseWolfTurn     GamePhase = "WOLF_TURN"     // Legacy (unused now)
	PhaseDoctorTurn   GamePhase = "DOCTOR_TURN"   // Legacy (unused now)
	PhaseWitchTurn    GamePhase = "WITCH_TURN"    // Legacy (unused now)
	PhaseSeerTurn     GamePhase = "SEER_TURN"     // Legacy (unused now)
	PhaseNightResolve GamePhase = "NIGHT_RESOLVE"
	PhaseDayStart     GamePhase = "DAY_START"
	PhaseDiscussion   GamePhase = "DISCUSSION"
	PhaseTestament    GamePhase = "TESTAMENT"
	PhaseVoting       GamePhase = "VOTING"
	PhaseVoteResolve  GamePhase = "VOTE_RESOLVE"
	PhaseElimination  GamePhase = "ELIMINATION"
	PhaseGameEnd      GamePhase = "GAME_END"
	PhaseResults      GamePhase = "RESULTS"
)

// IsNight returns true if the phase is a night phase
func (p GamePhase) IsNight() bool {
	return p == PhaseNight || p == PhaseNightStart || p == PhaseWolfTurn ||
		p == PhaseDoctorTurn || p == PhaseWitchTurn || p == PhaseSeerTurn ||
		p == PhaseNightResolve
}

// PlayerState represents a player in the game
type PlayerState struct {
	ID                 string                 `json:"id"`
	Name               string                 `json:"name"`
	Avatar             string                 `json:"avatar"`              // Legacy avatar ID
	AvatarID           int                    `json:"avatarId"`            // Profile avatar ID (1-12)
	ChibiConfig        map[string]interface{} `json:"chibiConfig"`         // Full chibi customization
	IsBot              bool                   `json:"isBot"`
	Role               Role                   `json:"role"`
	IsAlive            bool                   `json:"isAlive"`
	IsConnected        bool                   `json:"isConnected"`
	ProtectedThisNight  bool                   `json:"protectedThisNight"`
	HasConfirmedRole    bool                   `json:"hasConfirmedRole"` // #8 FIX: separate flag for role reveal confirmation
	DoctorProtectsUsed int                    `json:"doctorProtectsUsed"`
}

// WitchAction represents witch's action choice
type WitchAction struct {
	UseHeal      bool    `json:"useHeal"`
	PoisonTarget *string `json:"poisonTarget"`
}

// NightActions stores all night phase actions
type NightActions struct {
	WolfTarget        *string           `json:"wolfTarget"`
	WolfVotes         map[string]string `json:"wolfVotes,omitempty"`
	SeerTarget        *string           `json:"seerTarget"`
	SeerResult        *string           `json:"seerResult"`
	SeerSubmitterId   *string           `json:"seerSubmitterId,omitempty"`   // ID of seer who submitted first scan
	Seer2Target       *string           `json:"seer2Target"`
	Seer2Result       *string           `json:"seer2Result"`
	Seer2SubmitterId  *string           `json:"seer2SubmitterId,omitempty"`  // ID of seer who submitted second scan
	DoctorTarget      *string           `json:"doctorTarget"`
	WitchAction       *WitchAction      `json:"witchAction"`
	SubmittedPlayers  map[string]bool   `json:"submittedPlayers,omitempty"`
	CurrentTurn       string            `json:"currentTurn,omitempty"` // "werewolf","seer","doctor","witch"
}

// VoteRecord tracks votes
type VoteRecord struct {
	Votes       map[string]string `json:"votes"`
	Round       int               `json:"round"`
	IsRetry     bool              `json:"isRetry"`
	TiedPlayers []string          `json:"tiedPlayers,omitempty"`
}

// EliminationEvent records an elimination
type EliminationEvent struct {
	PlayerID string `json:"playerId"`
	Round    int    `json:"round"`
	Phase    string `json:"phase"` // "day" or "night"
	Role     string `json:"role"`
}

// Testament is a dead player's last words
type Testament struct {
	PlayerID   string `json:"playerId"`
	PlayerName string `json:"playerName"`
	Message    string `json:"message"`
	Round      int    `json:"round"`
	Phase      string `json:"phase"`
	Timestamp  int64  `json:"timestamp"`
}

// TimerConfig holds timer settings
type TimerConfig struct {
	Discussion  int `json:"discussion"`
	Voting      int `json:"voting"`
	NightAction int `json:"nightAction"`
	Testament   int `json:"testament"`
}

// GameConfig holds game configuration
type GameConfig struct {
	MinPlayers    int            `json:"minPlayers"`
	MaxPlayers    int            `json:"maxPlayers"`
	Roles         map[Role]int   `json:"roles"`
	TimerDuration TimerConfig    `json:"timerDuration"`
	Mode          string         `json:"mode"`
	FlexibleTimer bool           `json:"flexibleTimer"`
	HostID        string         `json:"hostId"`
}

// GameState is the full game state
type GameState struct {
	ID                       string             `json:"id"`
	Phase                    GamePhase          `json:"phase"`
	Round                    int                `json:"round"`
	Config                   GameConfig         `json:"config"`
	Players                  []PlayerState      `json:"players"`
	NightActions             NightActions       `json:"nightActions"`
	Votes                    VoteRecord         `json:"votes"`
	EliminationHistory       []EliminationEvent `json:"eliminationHistory"`
	Winner                   *Team              `json:"winner"`
	TimerDeadline            *int64             `json:"timerDeadline"`
	RetryVoteCount           int                `json:"retryVoteCount"`
	LastDoctorTarget         *string            `json:"lastDoctorTarget"`
	WitchHealUsed            bool               `json:"witchHealUsed"`
	WitchPoisonUsed          bool               `json:"witchPoisonUsed"`
	Testaments               []Testament        `json:"testaments"`
	PendingTestamentPlayerID *string            `json:"pendingTestamentPlayerId"`
	// M-2 FIX: Queue for multiple night deaths — each player gets testament in turn
	PendingTestamentQueue    []string           `json:"pendingTestamentQueue,omitempty"`
	Teammates                []TeammateInfo     `json:"teammates,omitempty"`
	Rewards                  *PlayerRewards     `json:"rewards,omitempty"`
	ResultsRecorded          bool               `json:"-"` // internal flag, not sent to client
}

// PlayerRewards contains the rewards earned by the current player
type PlayerRewards struct {
	XPEarned    int  `json:"xpEarned"`
	CoinsEarned int  `json:"coinsEarned"`
	Won         bool `json:"won"`
	Survived    bool `json:"survived"`
	NewLevel    int  `json:"newLevel,omitempty"`
	LeveledUp   bool `json:"leveledUp,omitempty"`
	MMRChange   int  `json:"mmrChange,omitempty"`
}

// TeammateInfo tells the client who their teammates are (visible during night)
type TeammateInfo struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role string `json:"role"`
}
