# Infrastructure

## Architecture

```
GitHub push → GitHub Actions → Cloud Build → Artifact Registry
                                                    ↓
                                   ┌─── Cloud Run (web) ←── HTTPS
                                   │         │
              Cloud SQL Postgres ──┤    Memorystore Redis
                                   │         │
                                   └─── Cloud Run (worker) ←── polling
                                   
Cloud Scheduler → Cloud Run Job (schedule:run) every 1 min
Cloud Run Job (migrate) ← triggered by CI/CD on deploy
Cloud Storage ← file uploads via Flysystem GCS adapter
```

**Runtime:** Laravel Octane + FrankenPHP on Cloud Run  
**Database:** Cloud SQL for PostgreSQL 16  
**Cache/Sessions/Queue broker:** Memorystore Redis 7.2  
**Queue worker:** Dedicated Cloud Run service polling Redis  
**Scheduler:** Cloud Run Job triggered every minute by Cloud Scheduler  
**Migrations:** Cloud Run Job executed during CI/CD before deploy  
**File storage:** Cloud Storage with Laravel Flysystem GCS adapter  
**Secrets:** Google Secret Manager (APP_KEY, DB_PASSWORD)  
**CI/CD:** GitHub Actions (orchestrator) + Cloud Build (build/deploy)  
**Infrastructure as Code:** Terraform with per-environment configs  

## File Overview

```
├── Makefile                    # All setup and operations commands
├── Dockerfile                  # Multi-stage: composer deps → Vite build → FrankenPHP
├── .dockerignore               # Keeps image lean
├── .gcloudignore               # Keeps Cloud Build uploads lean
├── cloudbuild.yaml             # Build image, run migrations, deploy all services
├── laravel-notes.php           # Health check route + logging config
├── laravel-filesystem.php      # GCS Flysystem setup instructions
│
├── .github/
│   ├── setup-wif.sh            # One-time: Workload Identity Federation setup
│   └── workflows/
│       ├── ci.yml              # Tests + lint on every PR
│       ├── build-deploy.yml    # Reusable: triggers Cloud Build, tracks result
│       ├── deploy-staging.yml  # Push to develop → deploy staging
│       ├── deploy-production.yml  # Push to main → deploy production
│       ├── manual-deploy.yml  # Manual deploy from GitHub UI
│       ├── infrastructure.yml # Terraform plan/apply from GitHub UI
│       └── preview.yml         # PR open → spin up env; PR close → tear down
│
└── terraform/
    ├── global/                 # Shared: Artifact Registry, APIs, state bucket
    │   └── main.tf
    ├── modules/environment/    # Reusable module for one full environment
    │   ├── main.tf             # Locals, secrets, conditional logic
    │   ├── variables.tf        # All configurable knobs
    │   ├── outputs.tf          # URLs, connection strings, DNS records
    │   ├── cloud-run.tf        # Web, worker, migrate job, scheduler job, domain
    │   ├── cloud-sql.tf        # Postgres instance, database, user (conditional)
    │   ├── redis.tf            # Memorystore (conditional)
    │   ├── networking.tf       # VPC connector
    │   └── storage.tf          # GCS uploads bucket
    └── environments/
        ├── production/         # HA database, HA Redis, always-warm, backups
        ├── staging/            # Minimal, scales to zero, no backups
        └── preview/            # Shares staging's DB + Redis, ephemeral
```

## First-Time Setup

Edit the variables at the top of the `Makefile` (`PROJECT_ID`,
`REGION`, `APP_NAME`), then run these in order:

```bash
make bootstrap         # 1. Artifact Registry, APIs, state bucket
```

Update the backend bucket name in each `terraform/environments/*/main.tf`
using the `state_bucket` output from step 1.

Edit the variables at the top of `.github/setup-wif.sh` (`PROJECT_ID`,
`GITHUB_ORG`, `GITHUB_REPO`), then:

```bash
make setup-wif         # 2. GitHub → GCP auth (Workload Identity Federation)
```

Add the three output values as GitHub repository secrets:
`GCP_PROJECT_ID`, `GCP_SERVICE_ACCOUNT`, `GCP_WORKLOAD_IDENTITY_PROVIDER`.

```bash
make build-initial     # 3. Build + push first image (Terraform needs it)
make init-staging      # 4. Deploy staging (preview envs depend on it)
make init-production   # 5. Deploy production
```

### DNS

If you set a `domain` in the environment config, check the DNS records
to create:

```bash
cd terraform/environments/production
terraform output dns_records
```

Create the CNAME records at your DNS provider. SSL certificates are
provisioned automatically and take 10–15 minutes.

### Laravel App Setup

Install Octane and the GCS adapter:

```bash
composer require laravel/octane league/flysystem-google-cloud-storage
php artisan octane:install --server=frankenphp
```

Add the health check route (see `laravel-notes.php`):

```php
// routes/web.php
Route::get('/health', function () {
    DB::connection()->getPdo();
    Cache::store('redis')->get('health-check');
    return response()->json(['status' => 'ok']);
});
```

Add the GCS disk to `config/filesystems.php` (see `laravel-filesystem.php`):

```php
'gcs' => [
    'driver' => 'gcs',
    'bucket' => env('GOOGLE_CLOUD_STORAGE_BUCKET'),
],
```

## Day-to-Day

### Deploys (automatic)

Push to `develop` → deploys to staging.  
Push to `main` → deploys to production.

CI runs tests on every PR. Preview environments spin up on PR open
and tear down on PR close — fully automated.

### Deploys (manual)

Go to **Actions → Manual Deploy → Run workflow**. Pick staging or
production and optionally specify a git ref.

### Infrastructure changes

Go to **Actions → Infrastructure → Run workflow**. Pick an environment
and choose `plan` to preview or `apply` to execute. This gives you
an audit trail of who changed what.

### Debugging

```bash
make db-connect-staging      # psql into staging
make db-connect-production   # psql into production
make logs-staging            # recent staging logs
make logs-production         # recent production logs
```

### Adding a new permanent environment

```bash
cp -r terraform/environments/staging terraform/environments/qa
# Edit qa/main.tf: change environment name, backend prefix, CIDR
```

Then use the **Infrastructure** workflow to plan and apply.

## CI/CD Workflows

### On every PR → `ci.yml`

Runs tests against real Postgres and Redis (GitHub Actions service
containers). Runs Pint linter. Gates the merge.

### Push to `develop` → `deploy-staging.yml`

GitHub Actions authenticates to GCP, triggers `gcloud builds submit`
with `_ENV=staging`, and waits for the result. Cloud Build builds the
image, runs migrations, and deploys web + worker + scheduler. The
GitHub Actions step summary includes a link to the Cloud Build logs.

### Push to `main` → `deploy-production.yml`

Same flow with `_ENV=production`. Uses `cancel-in-progress: false`
so a production deploy is never interrupted. You can add a GitHub
environment protection rule requiring manual approval.

### PR opened → `preview.yml`

Terraform creates Cloud Run services, VPC connector, storage bucket,
and a database on staging's Cloud SQL. Cloud Build builds and deploys.
GitHub Actions posts a comment on the PR with the preview URL.

### PR closed → `preview.yml` (teardown)

Terraform destroys all preview resources. Workspace is deleted.

### Manual deploy → `manual-deploy.yml`

Trigger from the GitHub Actions UI. Pick staging or production and
optionally a specific git ref. Calls the same `build-deploy.yml`
reusable workflow as the automated deploys.

### Infrastructure changes → `infrastructure.yml`

Trigger from the GitHub Actions UI. Pick an environment and choose
plan or apply. Runs Terraform with an audit trail in GitHub.

## Terraform Module

### How environments differ

| Setting | Production | Staging | Preview |
|---------|-----------|---------|---------|
| Cloud SQL | db-custom-2-8192, HA | db-f1-micro | Shares staging |
| Redis | 2GB, HA | 1GB, Basic | Shares staging |
| Web instances | 1–20, always warm | 0–3, scales to zero | 0–1 |
| Worker instances | 1–5 | 1 | 0–1 |
| Backups | Yes, 14 retained | No | No |
| Deletion protection | Yes | No | No |
| Storage versioning | Yes | No | No |

### Shared infrastructure

Preview environments set `shared_db_instance` and `shared_redis_host`,
which are pulled from staging's Terraform state via a
`terraform_remote_state` data source. Cloud SQL and Redis instance
creation is skipped entirely. Each preview env still gets its own
database, user, Cloud Run services, secrets, and storage bucket.

## Networking

Cloud Run services connect to:
- **Cloud SQL** via the built-in Cloud SQL Auth Proxy (volume mount at
  `/cloudsql/`). No VPC needed — it uses the Cloud SQL Admin API.
- **Memorystore Redis** via a Serverless VPC Access connector. Redis
  isn't publicly addressable, so the connector bridges Cloud Run to
  the VPC.

Each environment gets its own VPC connector with a unique /28 CIDR.
All environments share the `default` VPC.

## Secrets

`APP_KEY` and `DB_PASSWORD` are stored in Secret Manager and mounted
as environment variables on all Cloud Run services. Passwords are
generated by Terraform and never appear in config files.

## Cost Estimates

| Component | Production | Staging | Preview (per PR) |
|-----------|-----------|---------|------------------|
| Cloud SQL | ~$50–80/mo | ~$10/mo | $0 (shared) |
| Memorystore | ~$70/mo (HA) | ~$35/mo | $0 (shared) |
| Cloud Run web | Usage-based | Scales to zero | Scales to zero |
| Cloud Run worker | ~$15/mo | ~$15/mo | Scales to zero |
| VPC connector | ~$7/mo | ~$7/mo | ~$7/mo |
| Cloud Storage | < $1/mo | < $1/mo | < $1/mo |
| **Baseline** | **~$150–180/mo** | **~$70/mo** | **~$7/mo** |

Destroy preview environments when the PR is merged.

## Troubleshooting

### Cloud Build fails

Check the log link in the GitHub Actions step summary, or:

```bash
gcloud builds list --limit=5 --project=my-project
gcloud builds log BUILD_ID --project=my-project
```

### Migration fails

```bash
gcloud run jobs execute my-app-staging-migrate --region=us-east1 --wait
gcloud logging read \
  "resource.type=cloud_run_job AND resource.labels.job_name=my-app-staging-migrate" \
  --limit=50 --project=my-project
```

### Cloud Run service won't start

```bash
gcloud run services logs read my-app-staging-web --region=us-east1 --limit=50
```

Common causes: missing env vars, DB connection failed, Redis
unreachable (check VPC connector health).

### Connect to a database

```bash
make db-connect-staging
make db-connect-production
```

### View logs

```bash
make logs-staging
make logs-production
```

Or in the Cloud Logging console:
`resource.type="cloud_run_revision" resource.labels.service_name="my-app-production-web" severity>=ERROR`
