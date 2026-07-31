package filter

import (
	"testing"
)

func TestCensorProfanity(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "No profanity",
			input:    "Hello, how are you?",
			expected: "Hello, how are you?",
		},
		{
			name:     "Single profanity word",
			input:    "You are goblok",
			expected: "You are ******",
		},
		{
			name:     "Multiple profanity words",
			input:    "anjing goblok",
			expected: "****** ******",
		},
		{
			name:     "Mixed case",
			input:    "ANJING Goblok",
			expected: "****** ******",
		},
		{
			name:     "Leet speak substitution",
			input:    "g0bl0k",
			expected: "******",
		},
		{
			name:     "English profanity",
			input:    "What the fuck",
			expected: "What the ****",
		},
		{
			name:     "In sentence",
			input:    "Kamu itu tolol banget",
			expected: "Kamu itu ***** banget",
		},
		{
			name:     "Empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "Normal game chat",
			input:    "Aku yakin dia werewolf!",
			expected: "Aku yakin dia werewolf!",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CensorProfanity(tt.input)
			if result != tt.expected {
				t.Errorf("CensorProfanity(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestContainsProfanity(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected bool
	}{
		{"Clean text", "Hello world", false},
		{"Contains profanity", "You are goblok", true},
		{"Leet speak", "g0bl0k", true},
		{"Empty", "", false},
		{"Normal game chat", "Vote player 3!", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ContainsProfanity(tt.input)
			if result != tt.expected {
				t.Errorf("ContainsProfanity(%q) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestGetProfanityCount(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected int
	}{
		{"No profanity", "Hello world", 0},
		{"One word", "goblok", 1},
		{"Two words", "anjing goblok", 2},
		{"Empty", "", 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetProfanityCount(tt.input)
			if result != tt.expected {
				t.Errorf("GetProfanityCount(%q) = %d, want %d", tt.input, result, tt.expected)
			}
		})
	}
}
