package main

import "testing"

func TestParseCardBasic(t *testing.T) {
    cases := []struct{
        in string
        wantErr bool
    }{
        {"HA", false},
        {"S7", false},
        {"CT", false},
        {"X1", true},
        {"H10", true},
    }
    for _, c := range cases {
        _, err := parseCard(c.in)
        if (err != nil) != c.wantErr {
            t.Errorf("parseCard(%q) error = %v, wantErr %v", c.in, err, c.wantErr)
        }
    }
}

func TestRoyalFlush(t *testing.T) {
	// Royal flush: HA HK HQ HJ HT
	cards := []Card{
		{Rank: 12, Suit: 'H'}, // HA
		{Rank: 11, Suit: 'H'}, // HK
		{Rank: 10, Suit: 'H'}, // HQ
		{Rank: 9, Suit: 'H'},  // HJ
		{Rank: 8, Suit: 'H'},  // HT
		{Rank: 0, Suit: 'D'},  // D2 (filler)
		{Rank: 1, Suit: 'D'},  // D3 (filler)
	}

	score, err := evaluateHand(cards)
	if err != nil {
		t.Fatalf("evaluateHand failed: %v", err)
	}

	// Royal flush has rank 8 (straight flush)
	if score[0] != 8 {
		t.Errorf("Expected Royal Flush (rank 8), got rank %d", score[0])
	}

	name := getHandRankName(score[0])
	if name != "Straight Flush" {
		t.Errorf("Expected 'Straight Flush', got '%s'", name)
	}
}

func TestThreeOfAKind(t *testing.T) {
	// Three of a kind: HA HA HA HK HQ
	cards := []Card{
		{Rank: 12, Suit: 'H'}, // HA
		{Rank: 12, Suit: 'D'}, // DA
		{Rank: 12, Suit: 'C'}, // CA
		{Rank: 11, Suit: 'H'}, // HK
		{Rank: 10, Suit: 'H'}, // HQ
		{Rank: 0, Suit: 'D'},  // D2
		{Rank: 1, Suit: 'D'},  // D3
	}

	score, err := evaluateHand(cards)
	if err != nil {
		t.Fatalf("evaluateHand failed: %v", err)
	}

	if score[0] != 3 {
		t.Errorf("Expected Three of a Kind (rank 3), got rank %d", score[0])
	}
}

func TestPair(t *testing.T) {
	// Pair: HA HA HK HQ HJ
	cards := []Card{
		{Rank: 12, Suit: 'H'}, // HA
		{Rank: 12, Suit: 'D'}, // DA
		{Rank: 11, Suit: 'H'}, // HK
		{Rank: 10, Suit: 'H'}, // HQ
		{Rank: 9, Suit: 'H'},  // HJ
		{Rank: 0, Suit: 'D'},  // D2
		{Rank: 1, Suit: 'D'},  // D3
	}

	score, err := evaluateHand(cards)
	if err != nil {
		t.Fatalf("evaluateHand failed: %v", err)
	}

	if score[0] != 1 {
		t.Errorf("Expected Pair (rank 1), got rank %d", score[0])
	}
}

func TestGetHandRankName(t *testing.T) {
	tests := []struct {
		rank int
		want string
	}{
		{0, "High Card"},
		{1, "Pair"},
		{2, "Two Pair"},
		{3, "Three of a Kind"},
		{4, "Straight"},
		{5, "Flush"},
		{6, "Full House"},
		{7, "Four of a Kind"},
		{8, "Straight Flush"},
		{9, "Royal Flush"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			got := getHandRankName(tt.rank)
			if got != tt.want {
				t.Errorf("getHandRankName(%d) = %s, want %s", tt.rank, got, tt.want)
			}
		})
	}
}