#! /bin/bash

# Billing Account Function: Links a billing account to a project
link_billing_account() {

    local project_id=$1
    local primary_billing_name=$2
    local max_projects_per_account=5 # Adjust this threshold as needed

    # Check if any billing accounts are available 
    # Get the length of the list of billing accounts
    local billing_accounts_count=$(gcloud billing accounts list \
        --filter="OPEN=true" \
        --format="value(NAME)" | wc -l)

    if [ $billing_accounts_count -eq 0 ]
        then
            echo "ERROR: No billing accounts found. Please create a new billing account."
            return 1
    
    else 
        # Check current billing status
        local linked_billing_account=$(gcloud billing projects describe ${project_id} \
            --format="value(billingAccountName)" 2>/dev/null)
        
        if [ ! -z "$linked_billing_account" ]; then
            echo "Billing account already linked to the project."
            return 0
        fi

        # Fetch only the name of each OPEN billing account
        local fallback_billing_names=($(gcloud billing accounts list \
            --filter="OPEN=true" \
            --format="value(NAME)"))

        # Parse through all billing accounts from the billing accounts list.
        local all_billing_accounts=("$primary_billing_name" "${fallback_billing_names[@]}")
        
        for billing_name in "${all_billing_accounts[@]}"
            do
                echo "Trying billing account: $billing_name"
                
                # Get billing account ID
                local billing_account=$(gcloud billing accounts list \
                    --filter="NAME='${billing_name}' AND OPEN=true" \
                    --format="value(ACCOUNT_ID)")
                    
                if [ -z "$billing_account" ]
                    then
                        echo "Billing account $billing_name not found or not accessible. Trying next"
                        continue
                fi

                # Count the number of projects linked to this billing account
                local linked_projects_count=$(gcloud billing projects list \
                    --billing-account=${billing_account} \
                    --format="value(projectId)" | wc -l)
                

                if [ $linked_projects_count -lt $max_projects_per_account ]
                    then
                        echo "Linking project to billing account: $billing_name"
                        if gcloud beta billing projects link ${project_id} \
                            --billing-account=${billing_account}
                            then 
                                echo "Successfully linked billing account"
                                return 0
                        else
                            echo "Failed to link billing account. Trying next..."
                        fi
                else
                    echo "Billing account $billing_name has reached maximum projects limit ($max_projects_per_account). Trying next..."
                fi
        done

        echo "ERROR: Could not link any billing account. All accounts are either full or inaccessible."
        echo "Please create a new billing account."
        exit 1
    fi
}

# Function to list and check available billing accounts
check_billing_accounts() {
    echo "* ------------------------------------------------------------------------------------ *"
    echo "Checking for available billing accounts..."
    echo "* ------------------------------------------------------------------------------------ *"
    
    # Get all available billing accounts
    billing_accounts=$(gcloud billing accounts list --format="value(ACCOUNT_ID,NAME,OPEN)" 2>/dev/null | grep "True$" || echo "")
    
    if [ -z "$billing_accounts" ]; then
        echo "ERROR: No open billing accounts found."
        echo "Please create a new billing account in the Google Cloud Console:"
        echo "  https://console.cloud.google.com/billing"
        echo "After creating and setting up a billing account, run this script again."
        return 1
    else
        # Display available billing accounts
        echo "Available billing accounts:"
        echo "* ------------------------------------------------------------------------------------ *"
        gcloud billing accounts list --filter="OPEN=true" --format="table(ACCOUNT_ID,NAME,MASTER_ACCOUNT_ID)"
        echo "* ------------------------------------------------------------------------------------ *"
        return 0
    fi
}
