import re
import warnings
import pandas as pd
from google.cloud import secretmanager
from typing import Dict, Any


warnings.filterwarnings('ignore', 'Your application has authenticated using end user credentials')

def get_secret(gcp_secret: str, project_id: str) -> str:
    """
    This method is used to fetch secrets from a given 
    GCP Secret Manager key-storage.

    Args:
        gcp_secret: The name of the secret to fetch
        project_id: The GCP project ID

    Returns:
        The secret value
    """
    try: 
        client = secretmanager.SecretManagerServiceClient()
        request_secret = {"name": f"projects/{project_id}/secrets/{gcp_secret}/versions/latest"}
        response = client.access_secret_version(request=request_secret)
        secret = response.payload.data.decode("UTF-8")
        
        return secret

    except Exception as e: 
        print(e)


def convert_column(
        df: pd.DataFrame, 
        column_name: str, 
        target_type: str, 
        default_value = None
    ) -> pd.DataFrame:
    """
    Convert a column to the specified target type, handling NaN values.

    Args:
        df: The pandas DataFrame to convert
        column_name: The name of the column to convert
        target_type: The target type to convert the column to
        default_value: The default value to use if the column is NaN

    Returns:
        The pandas DataFrame with the converted column
    """

    default_values = {
        'INTEGER': 0,           # Default integer
        'FLOAT': 0.0,           # Default float
        'STRING': '',           # Default string
        'BOOLEAN': False,       # Default boolean
        'TIMESTAMP': pd.Timestamp('1970-01-01 00:00:00'), # Default timestamp
        'DATE': pd.Timestamp('1970-01-01').date(),        # Default date
    }

    # If column doesn't exist, return df unchanged
    if column_name not in df.columns:
        print(f"Warning: Column {column_name} not found")
        return df
    
    # Handle based on target type
    if target_type == 'INTEGER':
        df[column_name] = df[column_name].fillna(default_value or default_values['INTEGER']).astype('int64')
    
    elif target_type == 'FLOAT':
        df[column_name] = df[column_name].fillna(default_value or default_values['FLOAT']).astype('float64')
    
    elif target_type == 'STRING':
        # For strings, replace NaN with empty string (or specified default)
        df[column_name] = df[column_name].fillna(default_value or default_values['STRING']).astype('str')
        # Clean up 'nan' strings that might have been created
        df.loc[df[column_name] == 'nan', column_name] = default_value or default_values['STRING']
    
    elif target_type == 'BOOLEAN':
        # Handle various null representations for booleans
        if default_value is None:
            default_value = default_values['BOOLEAN']
        df[column_name] = df[column_name].fillna(default_value)
        # Convert non-boolean values to boolean
        df[column_name] = df[column_name].astype('bool')
    
    elif target_type in ('TIMESTAMP', 'DATETIME'):
        # For timestamps, either use NaT or convert to specified default
        if default_value is None:
            df[column_name] = pd.to_datetime(df[column_name], errors='coerce')
        else:
            df[column_name] = pd.to_datetime(df[column_name], errors='coerce').fillna(default_value or default_values['TIMESTAMP'])
    
    elif target_type == 'DATE':
        # Convert to datetime first, then extract date component
        temp_datetime = pd.to_datetime(df[column_name], errors='coerce')
        if default_value is None:
            df[column_name] = temp_datetime.dt.date
        else:
            df[column_name] = temp_datetime.fillna(default_value or default_values['DATE']).dt.date
    
    return df


def format_error_details(e: Exception) -> Dict[str, Any]:
    """
        Extract and format error details from various exception types using regex.
        
        Args:
            e: The exception object
        
        Returns:
            Dictionary containing formatted error details
    """

    error_details = {
        'type': type(e).__name__,
        'message': None,
        'status_code': None,
        'description': None,
        'retryable': None,
        'url': None  
    }
    
    # Convert the entire error to string for regex parsing
    error_str = str(e)
    
    # Special handling for HttpError messages
    if error_details['type'] == 'HttpError':
        # Extract URL from the error message
        url_pattern = r'requesting\s+(https?://[^\s"]+)'
        if url_match := re.search(url_pattern, error_str):
            error_details['url'] = url_match.group(1)
            
        # Extract the actual error message
        if 'Details: ' in error_str:
            error_details['message'] = error_str.split('Details: ')[-1].strip('">')
        elif 'returned "' in error_str:
            error_details['message'] = error_str.split('returned "')[1].split('"')[0]
        
        # For permission errors, prioritize the message after "Details:"
        if error_details['message'] and 'permission' in error_details['message'].lower():
            if 'Details: ' in error_str:
                error_details['message'] = error_str.split('Details: ')[-1].strip('">')
    
    elif error_details['type'] == 'TypeError':
        # Special handling for TypeError
        error_details['message'] = str(e)
        error_details['description'] = "Missing or incorrect argument provided to function"


    else:
        # Original message extraction for non-HttpError exceptions
        message_patterns = [
            r"'error':\s*'([^']*)'",  # Matches 'error': 'message'
            r'"error":\s*"([^"]*)"',  # Matches "error": "message"
            r'error:\s*([^\n,}]*)',   # Matches error: message
        ]
        
        for pattern in message_patterns:
            if match := re.search(pattern, error_str):
                error_details['message'] = match.group(1).strip()
                break
    
    # Extract error description (unchanged)
    description_patterns = [
        r"'error_description':\s*'([^']*)'",
        r'"error_description":\s*"([^"]*)"',
        r'error_description:\s*([^\n,}]*)',
    ]
    
    for pattern in description_patterns:
        if match := re.search(pattern, error_str):
            error_details['description'] = match.group(1).strip()
            break
    
    # Check for status code in different formats
    status_patterns = [
        r'status[_code]*[:=]\s*(\d+)',
        r'(\d{3})\s+[Ee]rror',
    ]
    
    for pattern in status_patterns:
        if match := re.search(pattern, error_str):
            error_details['status_code'] = int(match.group(1))
            break
            
    # Check exception attributes
    if hasattr(e, 'resp') and hasattr(e.resp, 'status'):
        error_details['status_code'] = e.resp.status
        
    if hasattr(e, 'retryable'):
        error_details['retryable'] = e.retryable
        
    # If no message found from regex, use str(e)
    if not error_details['message']:
        error_details['message'] = str(e)
        
    return error_details



def print_error_details(e: Exception, indent: str = "   ", bullet: str = "•") -> None:
    """
        Print formatted error details.
        
        Args:
            e: The exception object
            indent: Indentation string
            bullet: Bullet point character
    """
    details = format_error_details(e)
    border = border = "*" + "-"*100 + "*"
    
    print("\n" + border)
    print(f"{indent}{bullet} Error Type: {details['type']}")
    print(f"{indent}{bullet} Error Message: {details['message']}")
    
    if details['status_code']:
        print(f"{indent}{bullet} Error Status Code: {details['status_code']}")
        
    if details['description']:
        print(f"{indent}{bullet} Error Description: {details['description']}")
        
    if details['url']:
        print(f"{indent}{bullet} Failed URL: {details['url']}")
        
    if details['retryable'] is not None:
        print(f"{indent}{bullet} Retryable: {details['retryable']}")
    
    print(border + "\n")

    # If it's a TypeError, add additional context
    if details['type'] == 'TypeError':
        print(f"{indent}Suggestion: Check the function call and ensure all required arguments are provided.")
        print(f"{indent}Common fixes:")
        print(f"{indent}{indent}{bullet} Verify the function signature")
        print(f"{indent}{indent}{bullet}Check for missing positional arguments")
        print(f"{indent}{indent}{bullet} Ensure argument names match the function parameters\n")
