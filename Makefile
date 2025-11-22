up:
	docker-compose up --build

down:
	docker-compose down

.PHONY: benchmark
benchmark:
	@echo "Skipping benchmarks (not configured yet)."

