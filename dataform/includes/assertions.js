// definitions/assertions/transformed_assertions.js
const { ref, assert } = require('@dataform/core');


module.exports = (ref) => ({
    
    // Validates that the raw data is there before
    // running the incremental query. 
    checkSourceDataExists: (tableName) => `
        SELECT IF(
            COUNT(*) = 0,
            ERROR('No source data available for processing'),
            TRUE
        ) as assertion_result
        FROM ${ref(tableName)}
        WHERE DATE(date) = date_add(current_date(), interval -1 day)
    `,

    // Validates uniqueness of our data.
    uniqueCaseIds: (tableName) => `
        SELECT id 
        FROM ${ref(tableName)}
        GROUP BY id
        HAVING COUNT(*) > 1`,

    // Check for null values / missing data in critical fields
    checkCriticalFields: (tableName) => `
        SELECT IF(
            EXISTS (
                SELECT 1 
                FROM ${ref(tableName)}
                WHERE date IS NULL 
                   OR primary_type IS NULL 
                   OR community_area IS NULL
                   OR id IS NULL
            ),
            ERROR('Found NULL values in critical fields'),
            TRUE
        ) as assertion_result`,

    // Validate community area values are within expected range
    validateCommunityAreas: (tableName) => `
        SELECT IF(
            EXISTS (
                SELECT 1 
                FROM 
                    ${ref(tableName)}
                WHERE 
                    NOT REGEXP_CONTAINS(CAST(community_area AS STRING), r'^[0-9]+$')
                    OR CAST(community_area AS INT64) < 1 
                    OR CAST(community_area AS INT64) > 77
            ),
            ERROR('Invalid community area values found'),
            TRUE
        ) as assertion_result`,

    // Check for valid crime types
    validateCrimeTypes: (tableName) => `
        SELECT IF(
            EXISTS (
                SELECT 1 
                FROM ${ref(tableName)}
                WHERE primary_type NOT IN (
                    'HOMICIDE', 
                    'BATTERY', 
                    'THEFT', 
                    'ASSAULT', 
                    'BURGLARY'
                )
            ),
            ERROR('Invalid crime type found'),
            TRUE
        ) as assertion_result`,

    // Check for future dates in source
    checkFutureDates: (tableName) => `
        SELECT IF(
            EXISTS (
                SELECT 1 
                FROM ${ref(tableName)}
                WHERE DATE(date) > CURRENT_DATE()
            ),
            ERROR('Found future dates in source data'),
            TRUE
        ) as assertion_result`,


    // Verifies that the resulting schema matches what we 
    // expect to find. 
    schemaAssertion: (queryName) => {
        const schema = {
            event_date: "DATE",
            event_neighbourhood: "STRING", 
            homicide_count: "INTEGER",
            shootings_count: "INTEGER",
            theft_count: "INTEGER",
            assault_count: "INTEGER",
            burglary_count: "INTEGER"
        };

        const columnChecks = Object.keys(schema)
            .map(col => `CASE 
                WHEN typeof(${col}) = 'INT64' THEN 'INTEGER'
                WHEN typeof(${col}) = 'STRING' THEN 'STRING'
                WHEN typeof(${col}) = 'DATE' THEN 'DATE'
                ELSE typeof(${col})
            END as ${col}_type`)
            .join(',\n                ');

        return `
            WITH expected_schema AS (
                ${Object.entries(schema).map(([column, type]) => 
                    `SELECT '${column}' as column_name, '${type}' as expected_type`
                ).join(" UNION ALL ")
            }),
            actual_schema AS (
                SELECT 
                    column_name,
                    actual_type
                FROM ${queryName},
                UNNEST(
                    ARRAY[
                        ${Object.keys(schema).map(col => 
                            `STRUCT(
                                '${col}' as column_name, 
                                ${col}_type as actual_type
                            )`
                        ).join(',\n                ')}
                    ]
                )
                LIMIT 1
            )
            SELECT IF(
                EXISTS (
                    SELECT 1
                    FROM expected_schema e
                    LEFT JOIN actual_schema a
                    ON e.column_name = a.column_name
                    WHERE e.expected_type != a.actual_type
                    OR a.actual_type IS NULL
                ),
                ERROR('Schema validation failed'),
                TRUE
            ) as assertion_result
            `;
    }
});