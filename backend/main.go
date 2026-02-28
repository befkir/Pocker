package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

const httpAddr = ":8080"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	httpSrv := runHTTPServer(ctx)

	<-ctx.Done()
	log.Println("shutting down")
	httpSrv.Shutdown(context.Background())
}

func runHTTPServer(ctx context.Context) *http.Server {
	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
	})

	mux.HandleFunc("/poker/evaluate", handleEvaluate)
	mux.HandleFunc("/poker/compare", handleCompare)
	mux.HandleFunc("/poker/montecarlo", handleMonteCarlo)

	srv := &http.Server{
		Addr:    httpAddr,
		Handler: corsMiddleware(mux),
	}

	go func() {
		log.Printf("HTTP server listening on %s", httpAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("HTTP server failed: %v", err)
		}
	}()

	return srv
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// HTTP Request/Response types

type EvaluateRequest struct {
	HoleCards      []string `json:"hole_cards"`
	CommunityCards []string `json:"community_cards"`
}

type EvaluateResponse struct {
	Rank        string `json:"rank"`
	Description string `json:"description"`
}

type CompareRequest struct {
	FirstHole       []string `json:"first_hole_cards"`
	FirstCommunity  []string `json:"first_community_cards"`
	SecondHole      []string `json:"second_hole_cards"`
	SecondCommunity []string `json:"second_community_cards"`
}

type CompareResponse struct {
	Winner              int              `json:"winner"`
	FirstEvaluation     EvaluateResponse `json:"first_evaluation"`
	SecondEvaluation    EvaluateResponse `json:"second_evaluation"`
}

type MonteCarloRequest struct {
	HoleCards      []string `json:"hole_cards"`
	CommunityCards []string `json:"community_cards"`
	Players        int      `json:"players"`
	Simulations    int      `json:"simulations"`
}

type MonteCarloResponse struct {
	WinProbability float64 `json:"win_probability"`
}

// HTTP Handlers

func handleEvaluate(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req EvaluateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("400 Bad Request: failed to decode JSON: %v", err)
		http.Error(w, "invalid request: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Parse cards
	var holeCards []Card
	for _, card := range req.HoleCards {
		c, err := parseCard(card)
		if err != nil {
			log.Printf("400 Bad Request: invalid hole card: %s", card)
			http.Error(w, "invalid hole card: "+card, http.StatusBadRequest)
			return
		}
		holeCards = append(holeCards, c)
	}

	if len(holeCards) != 2 {
		log.Printf("400 Bad Request: must have exactly 2 hole cards, got %d", len(holeCards))
		http.Error(w, "must have exactly 2 hole cards", http.StatusBadRequest)
		return
	}

	var communityCards []Card
	for _, card := range req.CommunityCards {
		c, err := parseCard(card)
		if err != nil {
			http.Error(w, "invalid community card: "+card, http.StatusBadRequest)
			return
		}
		communityCards = append(communityCards, c)
	}

	if len(communityCards) < 0 || len(communityCards) > 5 {
		http.Error(w, "must have 0-5 community cards", http.StatusBadRequest)
		return
	}

	// Combine and pad to 7 cards
	allCards := append(holeCards, communityCards...)
	for len(allCards) < 7 {
		allCards = append(allCards, Card{})
	}

	score, err := evaluateHand(allCards)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resp := EvaluateResponse{
		Rank:        getHandRankName(score[0]),
		Description: getHandRankName(score[0]),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func handleCompare(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CompareRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("400 Bad Request (Compare): failed to decode JSON: %v", err)
		http.Error(w, "invalid request: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Evaluate first hand
	firstEval, err := evaluateCards(req.FirstHole, req.FirstCommunity)
	if err != nil {
		log.Printf("400 Bad Request (Compare): first hand error: %v", err)
		http.Error(w, "first hand error: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Evaluate second hand
	secondEval, err := evaluateCards(req.SecondHole, req.SecondCommunity)
	if err != nil {
		log.Printf("400 Bad Request (Compare): second hand error: %v", err)
		http.Error(w, "second hand error: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Determine winner
	var winner int
	if firstEval[0] > secondEval[0] {
		winner = 1
	} else if secondEval[0] > firstEval[0] {
		winner = 2
	}
	// If equal rank, compare kickers
	if firstEval[0] == secondEval[0] {
		if compareKickers(firstEval, secondEval) > 0 {
			winner = 1
		} else if compareKickers(firstEval, secondEval) < 0 {
			winner = 2
		}
	}

	resp := CompareResponse{
		Winner: winner,
		FirstEvaluation: EvaluateResponse{
			Rank:        getHandRankName(firstEval[0]),
			Description: getHandRankName(firstEval[0]),
		},
		SecondEvaluation: EvaluateResponse{
			Rank:        getHandRankName(secondEval[0]),
			Description: getHandRankName(secondEval[0]),
		},
	}

	json.NewEncoder(w).Encode(resp)
}

func handleMonteCarlo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req MonteCarloRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("400 Bad Request (MonteCarlo): failed to decode JSON: %v", err)
		http.Error(w, "invalid request: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Parse cards
	var holeCards []Card
	for _, card := range req.HoleCards {
		c, err := parseCard(card)
		if err != nil {
			log.Printf("400 Bad Request (MonteCarlo): invalid hole card: %s", card)
			http.Error(w, "invalid hole card: "+card, http.StatusBadRequest)
			return
		}
		holeCards = append(holeCards, c)
	}

	if len(holeCards) != 2 {
		log.Printf("400 Bad Request (MonteCarlo): must have exactly 2 hole cards")
		http.Error(w, "must have exactly 2 hole cards", http.StatusBadRequest)
		return
	}

	var communityCards []Card
	for _, card := range req.CommunityCards {
		c, err := parseCard(card)
		if err != nil {
			http.Error(w, "invalid community card: "+card, http.StatusBadRequest)
			return
		}
		communityCards = append(communityCards, c)
	}

	if len(communityCards) < 0 || len(communityCards) > 5 {
		http.Error(w, "must have 0-5 community cards", http.StatusBadRequest)
		return
	}

	prob := monteCarloWinProbability(holeCards, communityCards, req.Players, req.Simulations)

	resp := MonteCarloResponse{
		WinProbability: prob,
	}

	json.NewEncoder(w).Encode(resp)
}

// Helper function to evaluate cards
func evaluateCards(holeCards, communityCards []string) (HandValue, error) {
	var hole []Card
	for _, card := range holeCards {
		c, err := parseCard(card)
		if err != nil {
			return HandValue{}, err
		}
		hole = append(hole, c)
	}

	var community []Card
	for _, card := range communityCards {
		c, err := parseCard(card)
		if err != nil {
			return HandValue{}, err
		}
		community = append(community, c)
	}

	allCards := append(hole, community...)
	for len(allCards) < 7 {
		allCards = append(allCards, Card{})
	}

	return evaluateHand(allCards)
}
