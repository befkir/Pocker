package main

import (
	"errors"
	"math/rand"
	"sort"
	"strings"
)

// Card parsing and ranking logic for Texas Hold'em evaluation.
// Card format: suit (H/D/C/S) + rank (2-9,T,J,Q,K,A)
// Example: "HA" = Heart Ace, "S7" = Spade Seven

const rankOrder = "23456789TJQKA"

type Card struct {
	Rank int
	Suit byte
}

func (c Card) String() string {
	ranks := []string{"2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"}
	return string(c.Suit) + ranks[c.Rank]
}

func parseCard(card string) (Card, error) {
	card = strings.ToUpper(strings.TrimSpace(card))
	
	// Pre-process common aliases
	if strings.Contains(card, "10") {
		card = strings.Replace(card, "10", "T", 1)
	}

	if len(card) != 2 {
		return Card{}, errors.New("invalid card '" + card + "': must be 2 characters (e.g. 'HA' or 'AH')")
	}

	s1, s2 := card[0], card[1]
	suits := "HDCS"
	ranks := rankOrder

	// Try format 1: Suit + Rank (e.g. 'HA')
	if strings.ContainsAny(string(s1), suits) && strings.ContainsAny(string(s2), ranks) {
		rankIdx := strings.IndexAny(ranks, string(s2))
		return Card{Rank: rankIdx, Suit: s1}, nil
	}

	// Try format 2: Rank + Suit (e.g. 'AH')
	if strings.ContainsAny(string(s1), ranks) && strings.ContainsAny(string(s2), suits) {
		rankIdx := strings.IndexAny(ranks, string(s1))
		return Card{Rank: rankIdx, Suit: s2}, nil
	}

	return Card{}, errors.New("invalid card '" + card + "': use format like 'HA' (Heart Ace) or 'AH'")
}

// HandValue represents a hand as a 5-card value for comparison
// Format: 7 bytes - [rank, c1, c2, c3, c4] where rank is hand type (0-8)
// and c1-c4 are card values in descending order
type HandValue [5]int

// EvaluateHand takes 7 cards and returns the best 5-card hand
func evaluateHand(allCards []Card) (HandValue, error) {
	if len(allCards) != 7 {
		return HandValue{}, errors.New("need exactly 7 cards")
	}

	// Find the best 5-card hand from 7 cards
	best := HandValue{-1}
	combinations := combinations(allCards, 5)

	for _, five := range combinations {
		value := scoreHand(five)
		if value[0] > best[0] || 
			(value[0] == best[0] && compareKickers(value, best) > 0) {
			best = value
		}
	}
	return best, nil
}

// scoreHand evaluates a 5-card hand
func scoreHand(cards []Card) HandValue {
	ranks := make([]int, 5)
	suits := make(map[byte]int)
	for i, c := range cards {
		ranks[i] = c.Rank
		suits[c.Suit]++
	}

	sort.Slice(ranks, func(i, j int) bool { return ranks[i] > ranks[j] })

	isFlush := len(suits) == 1
	isStraight, straightHigh := checkStraight(ranks)

	// Return hand as [rankType, card1, card2, card3, card4]
	// rankType: 0=high, 1=pair, 2=two pair, 3=trips, 4=straight, 5=flush, 6=full house, 7=quads, 8=straight flush
	
	if isStraight && isFlush {
		if straightHigh == 12 { // A-K-Q-J-T
			return HandValue{8, 14, 0, 0, 0} // Royal flush
		}
		return HandValue{8, straightHigh, 0, 0, 0}
	}

	counts := countRanks(ranks)

	// Calculate frequencies of each rank count
	freqs := make(map[int]int)
	for _, count := range counts {
		freqs[count]++
	}

	// Four of a kind
	if freqs[4] > 0 {
		quads := findRank(ranks, 4)
		kicker := findRank(ranks, 1)
		return HandValue{7, quads, kicker, 0, 0}
	}

	// Full house
	if freqs[3] > 0 && freqs[2] > 0 || freqs[3] > 1 {
		trips := findRank(ranks, 3)
		var pair int
		if freqs[3] > 1 {
			// If we have two trips (e.g. 7 cards, 3 of one, 3 of another), the lower trip becomes the pair
			tripsList := findRanks(ranks, 3, 2)
			if tripsList[0] > tripsList[1] {
				trips = tripsList[0]
				pair = tripsList[1]
			} else {
				trips = tripsList[1]
				pair = tripsList[0]
			}
		} else {
			pair = findRank(ranks, 2)
            // handle multiple pairs in case of 7 cards
            if freqs[2] > 1 {
               pairsList := findRanks(ranks, 2, 3)
               pair = pairsList[0]
               for _, p := range pairsList {
                   if p > pair {
                       pair = p
                   }
               }
            }
		}
		return HandValue{6, trips, pair, 0, 0}
	}

	// Flush
	if isFlush {
		return HandValue{5, ranks[0], ranks[1], ranks[2], ranks[3]}
	}

	// Straight
	if isStraight {
		return HandValue{4, straightHigh, 0, 0, 0}
	}

	// Three of a kind
	if freqs[3] > 0 {
		trips := findRank(ranks, 3)
		kickers := findRanks(ranks, 1, 2)
        // Ensure reverse sorting of kickers
        sort.Slice(kickers, func(i, j int) bool { return kickers[i] > kickers[j] })
        
        k1, k2 := 0, 0
        if len(kickers) > 0 { k1 = kickers[0] }
        if len(kickers) > 1 { k2 = kickers[1] }
		return HandValue{3, trips, k1, k2, 0}
	}

	// Two pair
	if freqs[2] >= 2 {
		pairs := findRanks(ranks, 2, 3) // could have up to 3 pairs with 7 cards
		sort.Slice(pairs, func(i, j int) bool { return pairs[i] > pairs[j] })
		kicker := findRank(ranks, 1)
        // if we have 3 pairs, the 3rd pair is better than a regular kicker if it's higher
        if len(pairs) > 2 && pairs[2] > kicker {
            kicker = pairs[2]
        }
		return HandValue{2, pairs[0], pairs[1], kicker, 0}
	}

	// Pair
	if freqs[2] > 0 {
		pair := findRank(ranks, 2)
		kickers := findRanks(ranks, 1, 3)
        sort.Slice(kickers, func(i, j int) bool { return kickers[i] > kickers[j] })
        k1, k2, k3 := 0, 0, 0
        if len(kickers) > 0 { k1 = kickers[0] }
        if len(kickers) > 1 { k2 = kickers[1] }
        if len(kickers) > 2 { k3 = kickers[2] }
		return HandValue{1, pair, k1, k2, k3}
	}

	// High card
	return HandValue{0, ranks[0], ranks[1], ranks[2], ranks[3]}
}

// Helper functions
func countRanks(ranks []int) map[int]int {
	counts := make(map[int]int)
	for _, r := range ranks {
		counts[r]++
	}
	return counts
}

func findRank(ranks []int, count int) int {
	seen := make(map[int]bool)
	for _, r := range ranks {
		if !seen[r] {
			c := 0
			for _, rr := range ranks {
				if rr == r {
					c++
				}
			}
			if c == count {
				return r
			}
			seen[r] = true
		}
	}
	return -1
}

func findRanks(ranks []int, count, limit int) []int {
	var result []int
	seen := make(map[int]bool)
	for _, r := range ranks {
		if !seen[r] {
			c := 0
			for _, rr := range ranks {
				if rr == r {
					c++
				}
			}
			if c == count {
				result = append(result, r)
				if len(result) >= limit {
					return result
				}
			}
			seen[r] = true
		}
	}
	return result
}

func checkStraight(ranks []int) (bool, int) {
	// Check for A-2-3-4-5 (wheel)
	if ranks[0] == 12 && ranks[1] == 3 && ranks[2] == 2 && ranks[3] == 1 && ranks[4] == 0 {
		return true, 3 // In wheel, ace is low
	}
	// Check for regular straight
	for i := 1; i < 5; i++ {
		if ranks[i] != ranks[i-1]-1 {
			return false, -1
		}
	}
	return true, ranks[0]
}

func compareKickers(a, b HandValue) int {
	for i := 1; i < 5; i++ {
		if a[i] > b[i] {
			return 1
		}
		if a[i] < b[i] {
			return -1
		}
	}
	return 0
}

// Helper to generate combinations
func combinations(cards []Card, r int) [][]Card {
	var result [][]Card
	var combo []Card
	var backtrack func(int)
	backtrack = func(start int) {
		if len(combo) == r {
			tmp := make([]Card, r)
			copy(tmp, combo)
			result = append(result, tmp)
			return
		}
		for i := start; i < len(cards); i++ {
			combo = append(combo, cards[i])
			backtrack(i + 1)
			combo = combo[:len(combo)-1]
		}
	}
	backtrack(0)
	return result
}

// GetHandRankName returns the name of a hand rank
func getHandRankName(rankType int) string {
	names := []string{
		"High Card",
		"Pair",
		"Two Pair",
		"Three of a Kind",
		"Straight",
		"Flush",
		"Full House",
		"Four of a Kind",
		"Straight Flush",
		"Royal Flush",
	}
	if rankType >= 0 && rankType < len(names) {
		return names[rankType]
	}
	return "Unknown"
}

// MonteCarloWinProbability estimates the probability of winning via simulation
func monteCarloWinProbability(holeCards []Card, communityCards []Card, 
	numPlayers int, numSimulations int) float64 {
	
	if numPlayers < 2 {
		numPlayers = 2
	}
	if numSimulations < 100 {
		numSimulations = 100
	}

	wins := 0

	for i := 0; i < numSimulations; i++ {
		// Create remaining deck
		remaining := createDeck()
		remaining = removeCards(remaining, append(holeCards, communityCards...))

		// Complete community to 5 cards
		var community []Card
		community = append(community, communityCards...)
		for len(community) < 5 {
			idx := rand.Intn(len(remaining))
			community = append(community, remaining[idx])
			remaining = append(remaining[:idx], remaining[idx+1:]...)
		}

		// Deal cards to other players and evaluate
		myHand := append(holeCards, community...)
		myScore, _ := evaluateHand(myHand)

		// Check if we win against all other players
		wins += 1
		for p := 1; p < numPlayers; p++ {
			// Deal 2 cards to opponent
			var opponentCards []Card
			if len(remaining) >= 2 {
				opponentCards = append(opponentCards, remaining[0], remaining[1])
				remaining = remaining[2:]
			}
			opponentHand := append(opponentCards, community...)
			opponentScore, _ := evaluateHand(opponentHand)

			// Compare hands
			if compareHands(opponentScore, myScore) >= 0 {
				wins -= 1
				break
			}
		}
	}

	return float64(wins) / float64(numSimulations)
}

// compareHands returns 1 if a > b, -1 if a < b, 0 if equal
func compareHands(a, b HandValue) int {
	if a[0] != b[0] {
		if a[0] > b[0] {
			return 1
		}
		return -1
	}
	// Same rank type, compare kickers
	return compareKickers(a, b)
}

// Helper to create full deck
func createDeck() []Card {
	var deck []Card
	suits := []byte{'H', 'D', 'C', 'S'}
	for _, suit := range suits {
		for rank := 0; rank < 13; rank++ {
			deck = append(deck, Card{Rank: rank, Suit: suit})
		}
	}
	return deck
}

// Helper to remove cards from deck
func removeCards(deck []Card, toRemove []Card) []Card {
	for _, r := range toRemove {
		for i, d := range deck {
			if d.Rank == r.Rank && d.Suit == r.Suit {
				deck = append(deck[:i], deck[i+1:]...)
				break
			}
		}
	}
	return deck
}
