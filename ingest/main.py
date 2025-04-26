# make sure to install these packages before running:
# pip install pandas
# pip install sodapy
# pip freeze > requirements.txt

import os
import sys
import util
import json
import time
import logging
import requests
import pandas as pd
import functions_framework

from sodapy import Socrata
from dotenv import load_dotenv
from typing import List, Tuple
from datetime import date, timedelta, datetime

from google.cloud import bigquery
from google.cloud.workflows import executions_v1


# Configure logging.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Load in environment variables.
load_dotenv()
ENVIRONMENT = os.getenv('ENVIRONMENT')
APP_TOKEN_VALUE = os.getenv("SOCRATA_APP_TOKEN")
WORKFLOW_ID = os.getenv('WORKFLOW_ID')


def initClient(app_token_value: str) -> Socrata:
    """
    Initialize the Socrata client to access the Chicago Crime Data API.
    User must have an application token to access the data, which 
    should be created beforehand.

    Args:
        app_token_value: The value of the application token (if running locally)
    Returns:
        client: The initialized Socrata client
    """
    
    # Unauthenticated client only works with public datasets. Note 'None'
    # in place of application token, and no username or password
    try:
        client = Socrata(
            domain = "data.cityofchicago.org", 
            app_token = app_token_value,
        )
        logging.info(f"Socrata client initialized successfully")

        return client
    
    except Exception as e:
        logging.error(f"Error initializing Socrata client:")
        print(util.format_error_details(e))
        sys.exit(1)



def getDateRanges(
        start_date: date,
        end_date: date, 
        chunk_size: int = 365) -> List[Tuple[date, date]]:
    """
    Split a date range into chunks, ensuring the last chunk ends exactly at end_date.
    
    Args:
        start_date: Beginning of the date range
        end_date: End of the date range
        chunk_size: Number of days per chunk
    
    Returns:
        List of (start_date, end_date) tuples
    """

    date_ranges = []
    current_date = datetime.strptime(start_date, '%Y-%m-%d')
    end_date = datetime.strptime(end_date, '%Y-%m-%d')
    
    while current_date < end_date:
        chunk_end = min(current_date + timedelta(days=chunk_size), end_date)
        date_ranges.append((current_date, chunk_end))
        current_date = chunk_end + timedelta(days=1)
    
    return date_ranges



def needsBackfilling(
        project_id: str, 
        dataset_id: str,
        table_id: str, 
        client: bigquery.Client) -> Tuple[bool, date, date]: 
    """
    This method contains the logic to backfill data in case of 
    any failures. It will fetch the last successful date from the 
    BigQuery table and backfill the data from that date until the 
    current date.

    Args:
        project_id: The GCP project ID
        dataset_id: The BigQuery dataset ID
        table_id: The BigQuery table ID
        client: The BigQuery client

    Returns:
        A tuple containing a boolean indicating if backfilling is needed, 
        and the start and end dates.
    """

    sql = f"""
    -- Select the max partition id from the information schema for the table
    -- and return the date as a string.
    select
        ifnull(
            parse_date('%Y%m%d', partition_id),
            date('2001-01-01')
        )  as date
    from `{project_id}.{dataset_id}.INFORMATION_SCHEMA.PARTITIONS`
    where table_name = '{table_id}'
    order by date desc
    limit 1
    """

    try:
        query_job = client.query(sql)
        query_job.result()
        last_successful_date = None
        for row in query_job:
            last_successful_date = row['date']

        if not last_successful_date:
            logging.info("No last successful date found, backfilling from scratch...")
            return True, date(2001, 1, 1), date.today() - timedelta(days=1)
        
        logging.info(f"Last successful date: {last_successful_date}")

        # Take difference between last successful date and current date
        # and backfill the data from that date until the current date.
        date_diff = (date.today()-timedelta(days=1)) - last_successful_date
        
        if date_diff.days > 0:
            logging.info(f"We found {date_diff.days} days of missing data.")
            days = 0 if last_successful_date == '2001-01-01' else 1
            start_date = last_successful_date + timedelta(days=days)
            end_date = date.today() - timedelta(days=1)

            return True, start_date, end_date
        
        else:
            logging.info("Data is up to date.")
            return False, None, None
    
    except Exception as e:
        logging.error(f"Error fetching last successful date from BigQuery:")
        print(util.format_error_details(e))
        sys.exit(1)



def fetchData(
        client: Socrata, 
        limit: int, 
        start_date: str, 
        end_date: str) -> pd.DataFrame:
    """
    Fetch the Chicago Crime Data from the Socrata API 
    and return it as a pandas DataFrame.

    Args:
        client: The Socrata client
        limit: The number of records to fetch
        start_date: The start date
        end_date: The end date

    Returns:
        A pandas DataFrame containing the fetched data
    """
    all_data = []
    offset = 0
    start_date = str(start_date).split(' ')[0]
    end_date = str(end_date).split(' ')[0]
    
    # Specify query parameters for the API request.
    select_clause = [
        "id",
        "case_number",
        "date",
        "block",
        "primary_type",
        "arrest",
        "district",
        "description",
        "location_description",
        "ward",
        "community_area",
        "year",
        "updated_on",
        "latitude",
        "longitude",
        "location"
    ]
    select_clause = ",".join(select_clause)
    where_clause = f"date between '{start_date}' and '{end_date}'"
    where_clause += "\nand primary_type in ('THEFT','BATTERY','HOMICIDE','ASSAULT')"
    order_clause = "date desc"

    # Log progress
    print(f"Fetching data with pagination (page size: {limit})")
    
    while True:
        try:
            # Add retries for each request
            for attempt in range(5):
                try:
                    print(f"Fetching page at offset {offset}")
                    page_data = client.get(
                        dataset_identifier="ijzp-q8t2",
                        select=select_clause,
                        where=where_clause,
                        order=order_clause,
                        offset=offset,
                        limit=limit,
                    )
                    break  # Success, exit retry loop
                except requests.exceptions.Timeout:
                    if attempt < 4:  # Allow 5 attempts (0-4)
                        wait_time = 2 ** attempt  # Exponential backoff
                        print(f"Timeout occurred. Retrying in {wait_time} seconds...")
                        time.sleep(wait_time)
                    else:
                        raise  # Re-raise if all retries failed
            
            # Check if we got any data
            if not page_data:
                break  # No more data to fetch
                
            # Add this page to our results
            all_data.extend(page_data)
            print(f"Retrieved {len(page_data)} records. Total: {len(all_data)}")
            
            # Move to next page
            offset += limit
        
        except Exception as e:
            print(f"Error fetching data at offset {offset}: {e}")
            # Sleep and try the same page again
            time.sleep(5)
            continue
    
    # Convert to pandas DataFrame
    results_df = pd.DataFrame.from_records(all_data)
    logging.info(f"Data fetched successfully. Shape: {results_df.shape}")
    
    return results_df



def processData(df: pd.DataFrame) -> pd.DataFrame:
    """
    This method processes the data and returns a
    dataframe that is ready to be uploaded to BigQuery.
    Specifically, we ensure the column order and data
    types are correctly parsed.

    Args:
        df: The dataframe to be processed
    Returns:
        df: The processed dataframe
    """

     # Re-order columns to match BigQuery schema
    column_order = [
        'id',
        'date',
        'year',
        'case_number',
        'arrest',
        'primary_type',
        'description',
        'district',
        'ward',
        'community_area',
        'block',
        'location_description',
        'latitude',
        'longitude',
        'location',
        'updated_on'
    ]

    try: 
        df = df[column_order]

        # Format the date field into a BigQuery timestamp compatible format
        df.loc[:, 'updated_on'] = pd.to_datetime(df['updated_on'], format='%Y-%m-%dT%H:%M:%S.%f')
        
        # Strip the date field from the 'T' and following HH:MM:SS.000 Characters 
        df.loc[:, 'date'] = df['date'].str.split('T').str[0]
        df.loc[:, 'date'] = pd.to_datetime(df['date'], format='%Y-%m-%d')

        # Define the schema map for the columns
        schema_map = {
            'id': 'INTEGER',
            'date': 'DATE',
            'year': 'INTEGER',
            'case_number': 'STRING',
            'arrest': 'BOOLEAN',
            'primary_type': 'STRING',
            'description': 'STRING',
            'district': 'INTEGER',
            'ward': 'INTEGER',
            'community_area': 'INTEGER',
            'block': 'STRING',
            'location_description': 'STRING',
            'latitude': 'FLOAT',
            'longitude': 'FLOAT',
            'location': 'STRING',    
            'updated_on': 'TIMESTAMP'
        }

        # Converting ID fields to integers using loc
        for column, data_type in schema_map.items():
            df = util.convert_column(df, column, data_type)

        logging.info(f"Data processed successfully. Shape: {df.shape}")
        print(df.head())

        return df

    except Exception as e:
        logging.error(f"Error processing data:")
        print(util.format_error_details(e))
        
        sys.exit(1)



def uploadToBigQuery(df : pd.DataFrame, project_id: str) -> bool:
    """
    Creates the BigQuery dv360 incremental table
    and Uploads the processed data to it.

    Args:
        df: The dataframe to be uploaded
        project_id: The GCP project ID

    Returns:
        True if the data was uploaded successfully, False otherwise.
    """
    client = bigquery.Client(location="EU")
    dataset_ref = client.dataset("raw", project=project_id)
    table_ref = dataset_ref.table("chicago-crime-all")
    table_id = client.get_table(table_ref)

    job_config = bigquery.LoadJobConfig(
        schema=[
            bigquery.SchemaField("id", "INTEGER"),
            bigquery.SchemaField("date", "DATE"),
            bigquery.SchemaField("year", "INTEGER"),
            bigquery.SchemaField("case_number", "STRING"),
            bigquery.SchemaField("arrest", "BOOLEAN"),
            bigquery.SchemaField("primary_type", "STRING"),
            bigquery.SchemaField("description", "STRING"),
            bigquery.SchemaField("district", "INTEGER"),
            bigquery.SchemaField("ward", "INTEGER"),
            bigquery.SchemaField("community_area", "INTEGER"),
            bigquery.SchemaField("block", "STRING"),
            bigquery.SchemaField("location_description", "STRING"),
            bigquery.SchemaField("latitude", "FLOAT64"),
            bigquery.SchemaField("longitude", "FLOAT64"),
            bigquery.SchemaField("location", "STRING"),
            bigquery.SchemaField("updated_on", "TIMESTAMP")
        ],
        write_disposition="WRITE_APPEND"
    )

    try: 
        job = client.load_table_from_dataframe(
            dataframe = df, 
            destination = table_id, 
            job_config = job_config,
            job_id_prefix="chicago-load-job-raw-"
        )

        logging.info(f"Batch of Chicago Crime Data has been uploaded to raw table.")
        logging.info(f"Job ID: {job.job_id}")

        return True
                  
    except Exception as e:
        logging.error(f"Error uploading data to BigQuery:")
        print(util.format_error_details(e))

        return False



def triggerWorkflow(
        project_id: str, 
        location: str, 
        run_type: str,
        start_date: str,
        end_date: str,
        workflow_id: str, 
        env: str
    ) -> str:
    """
    Triggers a Cloud Workflows execution.
    
    Args:
        project_id (str): GCP project ID
        location (str): Workflow location (e.g., 'us-central1')
        workflow_id (str): Name/ID of the workflow to execute
        input_data (dict, optional): Input data to pass to the workflow
    
    Returns:
        execution_id: ID of the triggered workflow execution
    """

    try:

        if not all([project_id, workflow_id]):
            raise ValueError(
                "Missing required environment variables for Cloud Workflow: "
                "WORKFLOW_PROJECT_ID and WORKFLOW_NAME"
            )

        # Construct the fully qualified workflow path
        parent = f"projects/{project_id}/locations/{location}/workflows/{workflow_id}"

        # Create a Workflows client
        client = executions_v1.ExecutionsClient()

        # Prepare workflow parameters 
        workflow_params = {
            'env':env,
            'project_id': project_id,
            'lookup_table': 'run_log_dataform',
            'compilation': {
                'type': run_type,
                'start_date': start_date,
                'end_date': end_date
            }
        }

        # Create an execution object
        print("Building execution object")
        execution = executions_v1.Execution(
            argument=json.dumps(workflow_params).encode()
        )

        # Initialize request argument(s)
        print("Building execution request")
        request = executions_v1.CreateExecutionRequest(
            parent=parent,
            execution=execution
        )

        # Make the execution request
        print("Triggering Cloud Workflow")
        response = client.create_execution(
            request=request
        )

        print(f"Created execution: {response.name}")
        return response.name.split('/')[-1]

    except Exception as e:
        print(f"Error triggering Cloud Workflow: {e}")
        sys.exit(1)



def wait_for_execution(
        project_id: str, 
        location: str, 
        workflow_id: str, 
        execution_id: str,
        client: executions_v1.ExecutionsClient, 
        timeout_seconds=1800):
    """
    Waits for a workflow execution to complete.
    
    Args: 
        project_id: GCP project ID
        location: Workflow location (e.g., 'us-central1')
        workflow_id: Name/ID of the workflow
        execution_id: ID of the execution to wait for
        timeout_seconds: Maximum time to wait for the execution to complete

    Returns:
        The result of the workflow execution
    """

    execution_client = client
    execution_path = f"projects/{project_id}/locations/{location}/workflows/{workflow_id}/executions/{execution_id}"
    
    start_time = time.time()
    try:
        while True:
            if time.time() - start_time > timeout_seconds:
                raise TimeoutError("Workflow execution timed out")
                
            response = execution_client.get_execution(name=execution_path)
            
            if response.state == executions_v1.Execution.State.SUCCEEDED:
                return response.result
            
            elif response.state == executions_v1.Execution.State.FAILED:
                print(f"Workflow failed: {response.error.message}")

                return response.error.message
                
            time.sleep(2) 
    
    except Exception as e:
        print(f"Error waiting for workflow execution: {e}")
        sys.exit(1)



@functions_framework.http
def main(request):
    """
    Main function to run the ETL process.
    The request should be a JSON object with the 
    following structure:

    request = "{
        'run_type': 'daily'
    }"
    """

    # Initialize the list of date ranges to backfill.
    ranges = []
    request_json = request.get_json()
    payload = json.loads(request_json)
    
    run_type = payload['run_type']
    project_id = f"chicago-dataform-etl-{ENVIRONMENT}"

    logging.info("Request received, beginning process...")
    logging.info(f"Project ID: {project_id}")
    logging.info(f"Run type: {run_type}")
    logging.info(f"Payload: {payload}")
    

    # On any run, we want to check to see if 
    # the table needs backfilling. This can happen if the pipeline 
    # failed on previous days, or if the table is empty, in which
    # case we need to backfill the data from scratch.
    logging.info("Step 1: Determining date range for today's run...")
    logging.info(f"Checking if backfilling is required...")
    backfill, start_date, end_date = needsBackfilling(
        project_id=project_id,
        dataset_id="raw",
        table_id="chicago-crime-all",
        client=bigquery.Client(location="EU")
    )

    # If backfilling is required, we need to construct a list of date ranges
    # to backfill the data for. The list contains tuples of start and end 
    # dates which will be used in fetching batches of data from the API.
    if backfill:
        logging.info("Backfilling required, determining date ranges...")
        start_date = start_date.strftime('%Y-%m-%d')
        end_date = end_date.strftime('%Y-%m-%d')
        ranges = getDateRanges(
            start_date=start_date,
            end_date=end_date,
            chunk_size=365
        )
    
    # In cases where the table is up to date, we can just set the date ranges
    # to today's date.
    else:
        logging.info("No backfilling required, setting date ranges to today...")
        start_date = date.today().strftime('%Y-%m-%d')
        end_date = date.today().strftime('%Y-%m-%d')
        ranges.append((start_date, end_date))

    logging.info("Step 2: Initializing Socrata client...")
    client = initClient(
        app_token_value=APP_TOKEN_VALUE
    )

    logging.info("Step 3: Beginning data ingestion...")
    for range in ranges:
        # Specify the slice of data (based on the date range)
        # that we want to fetch from the API.
        start_date = range[0]
        end_date = range[1]

        # Fetch the data from the API
        logging.info(f"Fetching data for date range: {start_date} to {end_date} from Socrata...")
        data = fetchData(
            client =client, 
            limit = 500000,
            start_date =start_date,
            end_date = end_date
        )

        logging.info("Step 4: Processing data...")
        processed_data = processData(data)

        logging.info("Step 5: Uploading data to BigQuery...")
        load = uploadToBigQuery(
            df=processed_data,
            project_id=project_id
        )

        if load:
            continue
        else:
            logging.error("Error loading data to BigQuery.")
            return "FAILED"
        
    logging.info("Step 6: Running the Cloud Workflow instance...")

    execution_id=triggerWorkflow(
        project_id=project_id,
        location="europe-west1",
        run_type=run_type,
        start_date=start_date,
        end_date=end_date,
        workflow_id=WORKFLOW_ID,
        env=ENVIRONMENT
    )

    logging.info(f"Execution ID: {execution_id}")
    logging.info("Waiting for the workflow to complete")
    
    result = wait_for_execution(
        project_id=project_id,
        location="europe-west1",
        workflow_id=WORKFLOW_ID,
        execution_id=execution_id,
        client=executions_v1.ExecutionsClient()
    )

    logging.info(f"Workflow completed with result: {result}")
    return result
