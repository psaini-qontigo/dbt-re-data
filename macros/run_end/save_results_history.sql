
{% macro save_test_history(results) -%}

{{ adapter.dispatch('save_test_history_impl', 're_data') (results) }}

{%- endmacro %}

{% macro default__save_test_history_impl(results) %}
    -- depends_on: {{ ref('re_data_test_history') }}
    {% set command = flags.WHICH %}
    {% if execute and results and command in ('test', 'build') %}
        {% set tests = [] %}
        {% for el in results %}
            {% if el.node.resource_type.value == 'test' %}
                {% do tests.append(re_data.test_data_dict(el)) %}
            {% endif %}
        {% endfor %}

        {% if tests %}
            {% do re_data.insert_list_to_table(
                ref('re_data_test_history'),
                tests,
                ['table_name', 'column_name', 'test_name', 'status', 'execution_time', 'message', 'tested_records_count' ,'failures_count', 'failures_json', 'failures_table', 'severity', 'compiled_sql', 'run_at','additional_runtime_metadata', 'test_params', 'tags', 'test_config'],
                { 'run_at': timestamp_type() }
            ) %}
        {% endif %}

    {% endif %}
    {{ return ('') }}

{% endmacro %}

{% macro test_data_dict(el) %}

    {% set run_started_at_str = run_started_at.strftime('%Y-%m-%d %H:%M:%S') %}

    {% if el.node.to_dict().get('test_metadata') %}
        {% set any_refs = modules.re.findall("ref\(\'(?P<name>.*)\'\)", el.node.test_metadata.kwargs['model']) %}
        {% set any_source = modules.re.findall("source\(\'(?P<one>.*)\'\,\s+\'(?P<two>.*)\'\)", el.node.test_metadata.kwargs['model']) %}

        {% if any_refs %}
            {% set name = any_refs[0] %}
            {% set node_name = re_data.priv_full_name_from_depends(el.node, name) %}
            {% set schema = graph.nodes.get(node_name)['schema'] %}
            {% set database = graph.nodes.get(node_name)['database'] %}
            {% set table_name = (database + '.' + schema + '.' + name) | lower %} 
            
        {% elif any_source %}
            {% set package_name = any_source[0][0] %}
            {% set name = any_source[0][1] %}
            {% set node_name = re_data.priv_full_name_from_depends(el.node, name) %}
            {% set schema = graph.sources.get(node_name)['schema'] %}
            {% set database = graph.sources.get(node_name)['database'] %}
            {% set table_name = (database + '.' + schema + '.' + name) | lower %}
        {% else %}
            {% set table_name = none %}
        {% endif %}
    {% else %}
        {% set table_name = none %}
    {% endif %}

    {% if var.has_var('re_data:query_test_failures') %}
        {% set query_failures = var('re_data:query_test_failures') %}
    {% else %}
        {% set query_failures = true %}
    {% endif %}

    {% if el.failures and el.failures > 0 and el.node.relation_name and query_failures %}
        {% if var.has_var('re_data:test_history_failures_limit') %}
            {% set limit_count = var('re_data:test_history_failures_limit')%}
        {% else %}
            {% set limit_count = 10 %}
        {% endif %}

        {% set failures_query %}
            select * from {{ el.node.relation_name}} limit {{ limit_count }}
        {% endset %}
        {% set failures_list = re_data.agate_to_list(run_query(failures_query)) %}
    {% endif %}

    {% set failures_json = none %}

    {% if table_name %}
        {% set tested_records_query %}
            select count(*) as count from {{ table_name }}
            {% if el.node.config.get('where') %}
                where {{ el.node.config['where'] }}
            {% endif %}
        {% endset %}
        {% set tested_records_count = re_data.row_value(run_query(tested_records_query).rows[0],'count') %}
    {% else %}
        {% set tested_records_count = none %}
    {% endif %}
    
    {% if var.has_var('re_data:save_test_history_additional_runtime_metadata') %}
        {% set additional_runtime_metadata = {} %}
        {% for _var in var('re_data:save_test_history_additional_runtime_metadata').get('vars') %}
            {% if var.has_var(_var) %}
                {% do additional_runtime_metadata.update({_var:var(_var)}) %}
            {% endif %}
        {% endfor %}      
        {% for _env_var in var('re_data:save_test_history_additional_runtime_metadata').get('env_vars') %}
            {% if env_var(_env_var,'')|length>0 %}
                {% do additional_runtime_metadata.update({_env_var:env_var(_env_var)}) %}
            {% endif %}
        {% endfor %}
        {% set additional_runtime_metadata = tojson(additional_runtime_metadata) %}
    {% endif %}

    {% if var.has_var('re_data:save_test_history_test_params') %}
        {% set test_params = {} %}
        {% for _var in var('re_data:save_test_history_test_params') %}
            {% if var.has_var(_var) %}
                {% do test_params.update({_var:var(_var)}) %}
            {% endif %}
        {% endfor %}      
        {% set test_params = tojson(test_params) %}
    {% endif %}

    {{ return ({
        'table_name': table_name,
        'column_name': el.node.column_name or none,
        'test_name': el.node.name,
        'status': el.status.name,
        'execution_time': el.execution_time,
        'message': el.message,
        'tested_records_count': tested_records_count,
        'failures_count': el.failures,
        'failures_json': '' ~ failures_list,
        'failures_table': el.node.relation_name or none,
        'severity': el.node.config.severity,
        'compiled_sql': el.node.compiled_sql or el.node.compiled_code or none,
        'run_at': run_started_at_str,
        'additional_runtime_metadata': additional_runtime_metadata or none,
        'test_params': test_params or none,
        'tags': el.node.tags or none,
        'test_config': el.node.config.to_dict(omit_none=True) or none,

        })
    }}

{% endmacro %}

{% macro priv_full_name_from_depends(node, name) %}

    {% for full_name in node.depends_on.nodes %}
        {% set node_name = full_name.split('.')[-1] %}
        {% if node_name == name %}
            {{ return(full_name) }}
        {% endif %}
    {% endfor %}

    {{ return(none) }}

{% endmacro %}
