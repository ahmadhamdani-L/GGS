package filter

import (
	"regexp"
	"strings"
)

// Common Indonesian and English profanity words
// This list should be expanded based on community needs
var profanityWords = []string{
	// Indonesian
	"anjing", "anjg", "anjir", "ajg",
	"bangsat", "bngst",
	"kontol", "kntl", "kontl",
	"memek", "mmk", "memk",
	"ngentot", "ngtd", "entot",
	"babi", "babi lo", "babik",
	"goblok", "gblk", "goblog",
	"tolol", "tll", "tololl",
	"idiot",
	"bodoh", "bodo", "bdh",
	"setan", "setn",
	"tai", "taik",
	"sialan", "sialn",
	"kampret", "kmprt",
	"bajingan", "bjngn",
	"brengsek", "brngsk",
	"keparat", "kprt",
	"monyet", "mnyt",
	"asu",
	"jancok", "jancuk", "jnck",
	"cok", "cuk",
	"puki", "pukimak",
	// English
	"fuck", "fck", "f*ck", "fuk",
	"shit", "sh1t", "sht",
	"bitch", "b1tch", "btch",
	"ass", "a$$",
	"dick", "d1ck",
	"pussy", "puss",
	"bastard", "bstrd",
	"damn", "dmn",
	"crap",
	"cunt",
	"whore", "wh0re",
	"slut",
}

// Compiled regex patterns for faster matching
var profanityPatterns []*regexp.Regexp

func init() {
	profanityPatterns = make([]*regexp.Regexp, len(profanityWords))
	for i, word := range profanityWords {
		// Create case-insensitive pattern that matches word boundaries
		// Also matches common letter substitutions (0=o, 1=i, 3=e, 4=a, etc)
		pattern := strings.ReplaceAll(word, "a", "[a4@]")
		pattern = strings.ReplaceAll(pattern, "e", "[e3]")
		pattern = strings.ReplaceAll(pattern, "i", "[i1!]")
		pattern = strings.ReplaceAll(pattern, "o", "[o0]")
		pattern = strings.ReplaceAll(pattern, "s", "[s5$]")
		profanityPatterns[i] = regexp.MustCompile("(?i)" + pattern)
	}
}

// CensorProfanity replaces profanity words with asterisks
func CensorProfanity(text string) string {
	result := text
	for _, pattern := range profanityPatterns {
		result = pattern.ReplaceAllStringFunc(result, func(match string) string {
			return strings.Repeat("*", len(match))
		})
	}
	return result
}

// ContainsProfanity checks if text contains any profanity
func ContainsProfanity(text string) bool {
	lower := strings.ToLower(text)
	for _, pattern := range profanityPatterns {
		if pattern.MatchString(lower) {
			return true
		}
	}
	return false
}

// GetProfanityCount returns the number of profanity words found
func GetProfanityCount(text string) int {
	count := 0
	lower := strings.ToLower(text)
	for _, pattern := range profanityPatterns {
		matches := pattern.FindAllString(lower, -1)
		count += len(matches)
	}
	return count
}
