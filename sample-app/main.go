package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
}

func main() {
	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/health", healthHandler)
	http.Handle("/metrics", promhttp.Handler())

	log.Println("Starting server on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, "404").Inc()
		return
	}

	timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/"))
	defer timer.ObserveDuration()

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]string{
		"app":     "sample-app",
		"version": "1.0.0",
	}
	json.NewEncoder(w).Encode(resp)
	httpRequestsTotal.WithLabelValues(r.Method, "/", "200").Inc()
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	timer := prometheus.NewTimer(httpRequestDuration.WithLabelValues(r.Method, "/health"))
	defer timer.ObserveDuration()

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]string{
		"status": "healthy",
	}
	json.NewEncoder(w).Encode(resp)
	httpRequestsTotal.WithLabelValues(r.Method, "/health", "200").Inc()
}
