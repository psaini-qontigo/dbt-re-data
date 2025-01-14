{{
    config(
        materialized='incremental',
        on_schema_change='sync_all_columns',
    )
}}

{{
    re_data.empty_table_generic([
        ('table_name', 'string'),
        ('column_name', 'string'),
        ('test_name', 'string'),
        ('status', 'string'),
        ('execution_time', 'numeric'),
        ('message', 'string'),
        ('tested_records_count', 'numeric'),
        ('failures_count', 'numeric'),
        ('failures_json', 'long_string'),
        ('failures_table', 'long_string'),
        ('severity', 'string'),
        ('compiled_sql', 'long_string'),
        ('run_at', 'timestamp'),
        ('additional_runtime_metadata', 'long_string'),
        ('test_params', 'long_string'),
        ('tags', 'long_string'),
        ('test_config', 'long_string')
    ])
}}