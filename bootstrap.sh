#!/bin/bash

# This bootstrap script is used to automate the deployment of new Data Pipelines
# projects in Google Cloud Platform (GCP) using Terraform. Some prerequisites are 
# listed below:


# * -------------------------------------------------------------------------------- *
# Prerequisite (1) 
# * -------------------------------------------------------------------------------- *
# Before running, user must login to gcloud using `gcloud auth login` command.
# The user logging in must have the necessary permissions to create new
# projects and service accounts. The specific roles required are listed below:

    #   - roles/resourcemanager.projectCreator
    #   - roles/iam.serviceAccountAdmin
    #   - roles/iam.serviceAccountKeyAdmin
    #   - roles/iam.serviceAccountTokenCreator
    #   - roles/iam.workloadIdentityAdmin
    #   - roles/resourcemanager.projectIamAdmin


# * -------------------------------------------------------------------------------- *
# Prerequisite (2)
# * -------------------------------------------------------------------------------- *
# To run this, the following cli dependencies must be installed:
#  - gcloud Beta CLI extension
#  - gcloud Core CLI extension
#  - Terraform 


# * -------------------------------------------------------------------------------- *
# Prerequisite (3)
# * -------------------------------------------------------------------------------- *
# The user must have a billing account they can link to the new GCP project
# which is being created for this deployment. To find the billing account name,
# run the following command:
#   `gcloud beta billing accounts list`
# If there are no available billing accounts, create a new billing account and
# attach a new payment method to it in the Google Cloud Console:
#   https://console.cloud.google.com/billing



# Source confidential values from the .env file & helper functions
# Source the utils.sh file with helper functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/utils.sh"
source .env


# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install Terraform before running this script."
    echo "Installing Terraform..."
    brew install tfenv
    tfenv install 1.8.5
    tfenv use 1.8.5
fi


# Check if gcloud beta is installed
echo "----------------------------------------"
echo "Installing gcloud components if needed: "
echo "----------------------------------------"
echo "--> gcloud beta"
echo "--> gcloud core"
echo "----------------------------------------"

if ! gcloud components list --filter="name:beta" --format="get(state.name)" | grep -q "Installed"
    then 
        gcloud components install beta --quiet
        echo "gcloud beta installed successfully."
fi

if ! gcloud components list --filter="name:core" --format="get(state.name)" | grep -q "Installed"
    then
        gcloud components install core --quiet
        echo "gcloud core installed successfully."
fi

# Wait for the user to be authenticated
echo "Please authenticate with Google Cloud Platform..."
read -p "Press enter to continue..."

# Run through the gcloud auth login process
gcloud auth login

read -p "Press enter to confirm you've authenticated with GCP..."

# Specify the relevant environments
environments=("dev" "prod")

# Input for user's email address (to be used to auth to GCP)
read -p "Enter the email address you used to auth to GCP: " user_email
user_email=${user_email}

if ! [[ "$user_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Invalid email address. Please try again and enter a valid email address."
    exit 1
fi

# Set the user's email address as the default email address
echo "Setting the user's email address as the default email address..."
gcloud config set account $user_email 

# Input with a default value if user just hits enter
read -p "Enter a new project ID [press enter to use default: chicago-dataform-etl]: " user_input
user_input=${user_input:-chicago-dataform-etl}

# Check if the project ID is unique and not already in use, 
# and adheres to Google Cloud naming convention for projects
if ! [[ "$user_input" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "Project ID must:"
    echo "- Start with a letter"
    echo "- Contain only lowercase letters, numbers, and hyphens"
    echo "- End with a letter or number"
    echo "Please run the script again and enter a valid project ID."
    exit 1
fi

# Change directory to the environments folder
cd infra/environments

# Loop through the environments and create the necessary resources
for env in "${environments[@]}"; do

    # Check if the project has been created
    created=$(gcloud projects list --filter="projectId:${user_input}-${env}" --format="value(projectId)")
    echo "Project ID: ${created}"
    echo "Number of characters: ${#created}"

    # Check if the project with the same name already exists.
    if [ ${#created} == 0 ]; then

        echo "* ------------------------------------------------------------------------------------ *"
        echo "# Beginning Bootstrap / Initial Deployment for new Data Pipeline Project.."
        echo "* ------------------------------------------------------------------------------------ *"
        echo " ---> Creating a new project"
        echo " ---> Setting Project for gcloud CLI: ${user_input}"
        echo " ---> Enabling Billing for the Project"
        echo " ---> Setting variable names"
        echo "* ------------------------------------------------------------------------------------ *"

        # Create a new project
        gcloud projects create "${user_input}-${env}" \
            --name="Chicago Crime Dataform" 

    else
        echo "Project with the same name already exists. Continuing with the existing project."
    fi


    # Set the current project ID, if failed, specify the project ID manually
    gcloud config set project ${user_input}-${env}
    gcloud auth application-default set-quota-project "${user_input}-${env}"
    project_id=${user_input}-${env}
    bucket_name="${project_id}-tf-states"
    service_account="terraform"

    # Remove any trailing/leading whitespace
    bucket_name=$(echo "${bucket_name}" | xargs)
    project_id=$(echo "${project_id}" | xargs)

    # Call the function to check for billing accounts
    if ! check_billing_accounts; then
        exit 1
    fi

    # Input with a default value if user just hits enter
    read -p "Enter a billing account name [press enter to use default: 'My Billing Account']: " user_input_billing
    user_input_billing=${user_input_billing:-My Billing Account}

    # Call the link billing account function to link the billing account to the project
    link_billing_account \
        "${project_id}" \
        "${user_input_billing}"


    echo ""
    echo "* ------------------------------------------------------------------------------------ *"
    echo "Step 1: Enabling the following GCP APIs needed for Terraform to deploy our resources:"
    echo "* ------------------------------------------------------------------------------------ *"
    echo " ---> cloudbilling.googleapis.com"
    echo " ---> cloudresourcemanager.googleapis.com"
    echo " ---> billing.googleapis.com"
    echo " ---> iam.googleapis.com"
    echo " ---> iamcredentials.googleapis.com"
    echo " ---> sts.googleapis.com"
    echo " ---> serviceusage.googleapis.com"
    echo " ---> appengine.googleapis.com"
    echo " ---> compute.googleapis.com"  
    echo "* ------------------------------------------------------------------------------------ *"
    echo ""

    #* ---------------------------------------------------------------------------------------------------- *
    # Enable the IAM, Resource Manager, Service Account Credentials, and Security Token Service APIs etc.
    #* ---------------------------------------------------------------------------------------------------- *
    services=(
        "cloudbilling.googleapis.com"
        "cloudresourcemanager.googleapis.com" 
        "iam.googleapis.com" 
        "iamcredentials.googleapis.com" 
        "sts.googleapis.com" 
        "serviceusage.googleapis.com" 
        "appengine.googleapis.com"
        "compute.googleapis.com"
    )

    # List already enabled services, and enable 
    # only the services that are not enabled
    for service in "${services[@]}" 
        do
            # Use exact filtering with the service name
            if gcloud services list --enabled \
                --filter="config.name:${service}" \
                --format="get(config.name)" | grep -q "^${service}$" 
                then
                    echo "${service} is already enabled."
            else
                gcloud services enable "${service}" --quiet
                echo "${service} enabled successfully."
            fi
    done


    echo ""
    echo "* ------------------------------------------------------------------------------------ *"
    echo "  Step 2: Creating service account and granting it the necessary roles to run Terraform."
    echo "* ------------------------------------------------------------------------------------ *"
    echo " ---> roles/editor"
    echo " ---> roles/secretmanager.admin" 
    echo " ---> roles/iam.serviceAccountAdmin"
    echo " ---> roles/iam.serviceAccountTokenCreator"
    echo " ---> roles/iam.serviceAccountKeyAdmin"
    echo " ---> roles/resourcemanager.projectIamAdmin"
    echo " ---> roles/iam.workloadIdentityPoolAdmin"
    echo " ---> roles/storage.admin"
    echo "* ------------------------------------------------------------------------------------ *"
    echo ""

    # Create a new service account if it doesn't exist
    exists=$(gcloud iam service-accounts list \
        --project="${project_id}" \
        --filter="email=${service_account}@${project_id}.iam.gserviceaccount.com" \
        --format="value(email)"
    )

    if [ ${#exists} == 0 ] 
        then
            echo "Service account does not exist. Creating."
            gcloud iam service-accounts create "${service_account}" \
                --description="Deployment Service Account" \
                --display-name="Terraform" \
                --project="${project_id}"
    else
        echo "The Service account already exists."
    fi

    # First check if key file exists locally
    if [ -f "${service_account}.json" ]
        then
            echo "Key found locally, no need to create or delete existing keys."
    else
        echo "Checking existing service account keys"
        
        existing_keys=$(gcloud iam service-accounts keys list \
            --iam-account="${service_account}@${project_id}.iam.gserviceaccount.com" \
            --project="${project_id}" \
            --format="value(name)")

        if [ ! -z "$existing_keys" ]
            then
                echo "Found existing keys. Deleting oldest key..."
                oldest_key=$(echo "$existing_keys" | head -n 1)
                gcloud iam service-accounts keys delete "$oldest_key" \
                    --iam-account="${service_account}@${project_id}.iam.gserviceaccount.com" \
                    --project="${project_id}" \
                    --quiet
                
                echo "Deleted oldest key."
                echo "Creating new service account key..."
                
                if gcloud iam service-accounts keys create "${service_account}.json" \
                    --iam-account="${service_account}@${project_id}.iam.gserviceaccount.com" \
                    --project="${project_id}" \
                    --quiet
                        then
                            echo "Successfully created a new key for the service account."
                else
                    echo "Failed to create new service account key."
                    exit 1
                fi
        fi
    fi
    

    # Roles to grant to the service account
    roles=("roles/editor" 
        "roles/iam.serviceAccountAdmin"
        "roles/iam.serviceAccountKeyAdmin"
        "roles/iam.serviceAccountUser"
        "roles/iam.serviceAccountTokenCreator"
        "roles/iam.workloadIdentityPoolAdmin"
        "roles/resourcemanager.projectIamAdmin"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/secretmanager.secretAccessor"
        "roles/storage.admin"
        "roles/storage.objectAdmin"
        "roles/run.admin"
        "roles/bigquery.admin"
        "roles/artifactregistry.admin"
        "roles/cloudfunctions.admin"
        "roles/cloudscheduler.admin"
        "roles/workflows.admin"
        "roles/dataform.admin"
    )

    # Check if binding already exists
    for role in "${roles[@]}"
        do
            if ! gcloud projects get-iam-policy "${project_id}" \
                --flatten="bindings[].members" \
                --format='table(bindings.role,bindings.members)' \
                --filter="bindings.members:serviceAccount:${service_account}@${project_id}.iam.gserviceaccount.com AND bindings.role:${role}" | grep -q "${role}"
                
                then
                    echo "Adding role '${role}' to service account ${service_account}"
                    gcloud projects add-iam-policy-binding "${project_id}" \
                        --member="serviceAccount:${service_account}@${project_id}.iam.gserviceaccount.com" \
                        --role="${role}"
            else
                echo "Role '${role}' already exists for service account ${service_account}"
            fi
    done


    # Create GCS bucket for Terraform states
    echo ""
    echo "* ------------------------------------------------------------------------------------ *"
    echo "  Step 3: Creating GCS bucket for Terraform state"
    echo "* ------------------------------------------------------------------------------------ *"
    echo " ---> Bucket Name: ${bucket_name}"
    echo " ---> Location: EU"
    echo "* ------------------------------------------------------------------------------------ *"
    echo ""


    # Check if the bucket already exists
    echo "Bucket name: ${bucket_name}"
    echo "Project ID: ${project_id}"

    if ! gsutil ls -b "gs://${bucket_name}" >/dev/null 2>&1
        then
            echo "Bucket does not exist. Creating..."
            gsutil mb \
                -p ${project_id} \
                -c multi_regional \
                -l EU \
                gs://${bucket_name} 
    else
        echo "Bucket already exists."
    fi

    # wait for 5 seconds
    sleep 5

    # Get current IAM policy to ensure service account has necessary permissions
    # to configure the backend bucket for our Terraform config states
    roles=(
        "roles/storage.admin"
        "roles/storage.objectAdmin"
    )

    temp_file="temp_iam_policy.json"
    touch "$temp_file"

    if ! gsutil iam get gs://${bucket_name}/ > "$temp_file" 
        then
            echo "Error: Failed to get IAM policy for bucket gs://${bucket_name}"
            rm "$temp_file"
    fi

    for role in "${roles[@]}"
        do
            if grep -q "serviceAccount:${service_account}@${project_id}.iam.gserviceaccount.com.*${role}" "$temp_file"
                then
                    echo "Service account already has ${role} permission on gs://${bucket_name}"
            else
                echo "Granting ${role} permission to service account..."
                gsutil iam ch \
                    serviceAccount:${service_account}@${project_id}.iam.gserviceaccount.com:${role} \
                    gs://${bucket_name}/
            fi
    done
    rm "$temp_file"

    # Run terraform deployment sequence
    echo ""
    echo "* ------------------------------------------------------------------------------------ *"
    echo "  Step 4: Running Terraform Deployment Sequence"
    echo "* ------------------------------------------------------------------------------------ *"
    echo " ---> Initializing Terraform"
    echo " ---> Running Terraform Plan"
    echo " ---> Applying Terraform Plan"
    echo "* ------------------------------------------------------------------------------------ *"
    echo ""

    # Set the service account to be used by Terraform
    gcloud auth activate-service-account \
        --key-file="${service_account}.json" \
        --quiet

    gcloud config set account \
        "${service_account}@${project_id}.iam.gserviceaccount.com" \
        --quiet 


    # Echo back the current environment
    echo "Current Environment: ${env}"

    # Initialize Terraform with env specific backend config
    terraform init \
        -reconfigure \
        -backend-config="bucket=${bucket_name}" \
        -backend-config="prefix=terraform/state/${env}" \
        -backend-config="credentials=${service_account}.json"

    # Run Terraform Plan
    terraform plan \
        -var-file="${env}/vars.auto.tfvars" \
        -var="github_token=${GITHUB_TOKEN}" \
        -var="gcf_socrata_app_token=${SOCRATA_APP_TOKEN}" \
        -input=false \
        -out="${env}.tfplan"

    # Apply Terraform Plan
    terraform apply \
        -input=false \
        -auto-approve \
        ${env}.tfplan

    gcloud config set account $user_email

done
