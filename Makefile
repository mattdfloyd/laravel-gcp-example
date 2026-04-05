.PHONY: help bootstrap setup-wif build-initial init-staging init-production db-connect-staging db-connect-production logs-staging logs-production

# ── Configuration ─────────────────────────────

PROJECT_ID   ?= my-project
REGION       ?= us-east1
APP_NAME     ?= my-app
IMAGE_REPO   ?= $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(APP_NAME)-repo/$(APP_NAME)

# ── Help ──────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ── First-Time Setup (run once, in order) ────

bootstrap: ## 1. Create shared resources (Artifact Registry, APIs, state bucket)
	cd terraform/global && \
		terraform init && \
		terraform apply -var="project_id=$(PROJECT_ID)"

setup-wif: ## 2. Set up GitHub → GCP authentication (edit vars in script first)
	chmod +x .github/setup-wif.sh && ./.github/setup-wif.sh

build-initial: ## 3. Build and push the first image
	gcloud builds submit \
		--tag $(IMAGE_REPO):initial \
		--project $(PROJECT_ID)

init-staging: ## 4. Deploy staging infrastructure
	cd terraform/environments/staging && \
		terraform init && \
		terraform apply \
			-var="project_id=$(PROJECT_ID)" \
			-var="image=$(IMAGE_REPO):initial"

init-production: ## 5. Deploy production infrastructure
	cd terraform/environments/production && \
		terraform init && \
		terraform apply \
			-var="project_id=$(PROJECT_ID)" \
			-var="image=$(IMAGE_REPO):initial"

# ── Debugging ─────────────────────────────────

db-connect-staging: ## Connect to staging database
	@echo "Password:"
	@gcloud secrets versions access latest \
		--secret=$(APP_NAME)-staging-db-password \
		--project=$(PROJECT_ID)
	@echo ""
	cloud-sql-proxy $(PROJECT_ID):$(REGION):$(APP_NAME)-staging-db &
	@sleep 2
	psql -h 127.0.0.1 -U laravel -d laravel

db-connect-production: ## Connect to production database
	@echo "Password:"
	@gcloud secrets versions access latest \
		--secret=$(APP_NAME)-production-db-password \
		--project=$(PROJECT_ID)
	@echo ""
	cloud-sql-proxy $(PROJECT_ID):$(REGION):$(APP_NAME)-production-db &
	@sleep 2
	psql -h 127.0.0.1 -U laravel -d laravel

logs-staging: ## View recent staging web logs
	gcloud logging read \
		'resource.type="cloud_run_revision" resource.labels.service_name="$(APP_NAME)-staging-web"' \
		--limit=50 --format=json --project=$(PROJECT_ID)

logs-production: ## View recent production web logs
	gcloud logging read \
		'resource.type="cloud_run_revision" resource.labels.service_name="$(APP_NAME)-production-web"' \
		--limit=50 --format=json --project=$(PROJECT_ID)

.DEFAULT_GOAL := help
