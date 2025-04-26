# Project Structure

## Ingestion Layer

- The **`ingest`** directory contains the logic for fetching the raw crime data from the City of Chicago crime data portal. This logic is packaged as a Cloud Run function and is invoked every day by a Cloud Scheduler instance.

    - **ingest/**
        - `main.py`: Contains the core logic for fetching raw data with the Socrata API client (using SoQL), processes the raw data and stores it in a BigQuery table.
        - `util.py`: Contains helper methods used throughout the `main.py` file. 
        - `requirements.txt`: List of python SDK libraries to be installed in the Cloud function container image.


## Data Layer

- The **`dataform`** directory contains the data models for transforming and loading the processed crime data from which is stored in our raw BigQuery table. The logic is contained in our `crimes_transformed.sqlx`file. 

    - **dataform/**
        - `workflow_settings.yaml`: Contains configuration of the Dataform project, including any project variables and compilation overrides. 
        - `package.json`: Contains package setting where we reference the libraries / npm packages available for use in our Dataform project.
    
    - **dataform/definitions**
        - `core`: Contains the core ETL logic for transforming our raw data.
        - `sources`: Contains the reference (declaration) to our raw BigQuery table from which we fetch raw data. 
        
    - **dataform/includes**
        - `assertions.js`: Contains the set of assertions / tests which validate the quality and integrity of our raw data.
        - `constants.js`: Contains the references to variables used throughout the `crimes_transformed.sqlx` file. 
        - `utils.js`: Contains utility functions (in our case, a primary key generation method) used in our `crimes_transformed.sqlx` file.


## Orchestration Layer
The orchestration layer is implemented using Google Cloud Workflows and Cloud Scheduler to automate the data processing pipeline:

- **Cloud Scheduler**: Triggers the ingestion process on a scheduled basis.
- **Cloud Workflows**: Manages the execution of data processing steps in sequence.
    - `orchestration/pipeline.yaml`: Contains the jobs and steps that make API calls to the Dataform APIs which execute our dataform project. 


## Infrastructure Management Layer
The infrastructure is managed using Terraform with a modular structure for better maintainability and separation of concerns:

- **infra/environments**: Contains the main Terraform configuration files that bring together all infrastructure modules.
  - `main.tf`: Defines all module instantiations and dependencies.
  - `variables.tf`: Defines all input variables for the Terraform configuration.
  
- **infra/modules**: Contains specialized Terraform modules for each component of the infrastructure:
  - `bigquery`: Sets up datasets and tables for raw, staging, and transformed data.
  - `dataform`: Configures the Dataform repository and workspace for data transformations.
  - `gcf`: Deploys the Cloud Function for data ingestion.
  - `github`: Manages the GitHub repository for version control.
  - `iam`: Sets up service accounts and IAM roles.
  - `scheduler`: Configures Cloud Scheduler for triggering the data pipeline.
  - `secret_manager`: Manages secrets like API tokens.
  - `services`: Enables required Google Cloud APIs.
  - `wif`: Sets up Workload Identity Federation for GitHub Actions integration.
  - `workflows`: Configures Cloud Workflows for orchestration.

The infrastructure is designed to support a fully automated data pipeline from ingestion to transformation, with appropriate security controls and service account permissions.

## CI/CD Layer
The CI/CD (Continuous Integration and Continuous Deployment) processes are implemented using GitHub Actions workflows to automate testing, validation, and deployment of infrastructure changes:

- **`.github/workflows/cicd-dev.yml`**: Automates deployment to the development environment.
  - Triggers on push to the `dev` branch when changes are made to infrastructure or source code.
  - Authenticates to Google Cloud using Workload Identity Federation.
  - Executes Terraform init, plan, and apply to deploy infrastructure to the development project.
  - Uses environment-specific variables and secrets from the dev environment.

- **`.github/workflows/cicd-prod.yml`**: Automates deployment to the production environment.
  - Triggers on push to the `main` branch for infrastructure or source code changes.
  - Similar to the dev workflow but targets the production Google Cloud project.
  - Includes additional steps like Terraform format checking.
  - Uses production-specific environment variables and credentials.

- **`.github/workflows/lint-dev.yml`**: Validates infrastructure changes in pull requests to the dev branch.
  - Executes Terraform plan to detect potential issues before merging.
  - Posts the plan results as comments in the pull request for easier review.
  - Analyzes the plan output for resource changes and potential errors.
  - Helps developers identify problems early in the development process.

- **`.github/workflows/lint-prod.yml`**: Similar to lint-dev but for pull requests to the production branch.
  - Provides an additional safety net for production deployments.
  - Ensures that proposed changes are validated before reaching the main branch.

This CI/CD approach enforces a dev-to-prod promotion model, where changes are first tested and deployed to development before being promoted to production, reducing risks and ensuring consistent, reliable deployments.

### Required GitHub Repository Secrets

For the CI/CD workflows to function properly, the following secrets must be added to your GitHub repository:

- **`GHA_TOKEN`**: GitHub personal access token with appropriate permissions for repo and workflow operations.
- **`SOCRATA_APP_TOKEN`**: API token for accessing the Chicago crime data from the Socrata API.
- **`PROVIDER_NAME_DEV`**: Full resource name of the Workload Identity Federation provider for the dev environment.
- **`PROVIDER_NAME_PROD`**: Full resource name of the Workload Identity Federation provider for the prod environment.
- **`SERVICE_ACCOUNT_EMAIL_DEV`**: Email address of the service account in the dev GCP project.
- **`SERVICE_ACCOUNT_EMAIL_PROD`**: Email address of the service account in the prod GCP project.

To add these secrets:
1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Click "New repository secret" and add each of the secrets above

### Finding Workload Identity Federation Provider Names

The Workload Identity Federation provider names can be found in your GCP projects:

1. Go to the Google Cloud Console
2. Navigate to IAM & Admin > Workload Identity Federation
3. Select the appropriate pool (usually "github-pool")
4. The provider name will be in the format:
   ```
   projects/{project-number}/locations/global/workloadIdentityPools/{pool-id}/providers/{provider-id}
   ```

You'll need to get this information for both your development and production GCP projects and add them as the `PROVIDER_NAME_DEV` and `PROVIDER_NAME_PROD` secrets respectively.

______________________________________________

# Usage

## Initial Deployment Guide

This guide will walk you through the initial deployment of the Chicago Crime Dataform project. The process leverages the `bootstrap.sh` script which automates much of the setup.

### Prerequisites

- Git installed locally
- Google Cloud CLI installed and configured
- Terraform CLI installed (version 1.8.5 or compatible)
- GitHub personal access token with appropriate permissions
- GCP project(s) created for development and production

### Deployment Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/vinceyordanov96/chicago-crime-dataform.git
   cd chicago-crime-dataform
   ```

2. **Create the development branch**
   ```bash
   git checkout -b dev
   ```
   
   This branch is essential for the dev/prod environment duality in our CI/CD workflow.

3. **Configure environment variables**
   
   Create a `.env` file with required variables:
   ```
   GCP_PROJECT_ID_DEV=your-dev-project-id
   GCP_PROJECT_ID_PROD=your-prod-project-id
   GITHUB_TOKEN=your-github-personal-access-token
   ```

4. **Run the bootstrap script**
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```
   
   The script will:
   - Enable necessary Google Cloud APIs
   - Set up service accounts and IAM permissions
   - Configure Workload Identity Federation
   - Create the initial infrastructure using Terraform
   - Initialize the GitHub repositories and workflows

5. **Commit and push changes with [skip ci] flag**
   ```bash
   git add .
   git commit -m "Initial bootstrap deployment [skip ci]"
   git push origin -u dev
   ```
   
   **Important**: The `[skip ci]` flag in the commit message is crucial as it prevents the CI/CD workflows from triggering another deployment, which would conflict with the bootstrap process. Without this flag, GitHub Actions would attempt to redeploy the same infrastructure that was just created.

### Deploying to Production

Once the development environment is stable and tested:

1. **Create a Pull Request**
   - Go to your GitHub repository
   - Create a new Pull Request to merge the `dev` branch into the `main` branch
   - Provide a detailed description of the changes being promoted to production

2. **Review and Approve**
   - The `lint-prod.yml` workflow will automatically run and validate the infrastructure changes
   - Review the Terraform plan in the PR comments
   - Request reviews from team members if needed

3. **Merge the Pull Request**
   - Once approved, merge the PR
   - The `cicd-prod.yml` workflow will automatically deploy the changes to the production environment

### Subsequent Deployments

For future changes:

1. Always work in the `dev` branch or feature branches that get merged to `dev`
2. Let the CI/CD process handle deployments (don't run bootstrap.sh again)
3. Use PRs to promote changes from `dev` to `main` (development to production)

### Troubleshooting

If you encounter issues during deployment:

- Check the GitHub Actions logs for detailed error messages
- Verify GCP permissions and service account setup
- Ensure Workload Identity Federation is properly configured
- Review Terraform state for potential conflicts
