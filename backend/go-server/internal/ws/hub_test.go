package ws

import (
	"testing"
)

func TestGenerateID_Length(t *testing.T) {
	id := generateID()
	if len(id) != 32 { // 16 bytes = 32 hex chars
		t.Errorf("Expected 32 char hex ID, got %d chars: %s", len(id), id)
	}
}

func TestGenerateID_Unique(t *testing.T) {
	ids := make(map[string]bool)
	for i := 0; i < 1000; i++ {
		id := generateID()
		if ids[id] {
			t.Fatalf("Duplicate ID generated: %s", id)
		}
		ids[id] = true
	}
}

func TestGenerateRoomCode_Format(t *testing.T) {
	code := generateRoomCode()
	if len(code) != 6 {
		t.Errorf("Expected 6 char code, got %d: %s", len(code), code)
	}
	for _, c := range code {
		if c < 'A' || c > 'Z' {
			if c < '0' || c > '9' {
				t.Errorf("Invalid char in room code: %c", c)
			}
		}
	}
}

func TestNewHub_Defaults(t *testing.T) {
	h := NewHub()
	if h.workerCount < 4 {
		t.Errorf("Expected at least 4 workers, got %d", h.workerCount)
	}
	if h.maxRooms != 100 {
		t.Errorf("Expected default maxRooms=100, got %d", h.maxRooms)
	}
	if h.userIndex == nil {
		t.Error("userIndex should be initialized")
	}
	if h.clients == nil {
		t.Error("clients map should be initialized")
	}
}

func TestSafeSend_NilClient(t *testing.T) {
	// safeSend should not panic on nil client
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("safeSend panicked: %v", r)
		}
	}()
	safeSend(nil, &Message{Type: "test"})
}

func TestSafeSend_ClosedChannel(t *testing.T) {
	// safeSend should not panic on closed channel
	c := &Client{Send: make(chan *Message, 1)}
	close(c.Send)
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("safeSend panicked on closed channel: %v", r)
		}
	}()
	safeSend(c, &Message{Type: "test"})
}
