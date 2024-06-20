#!/bin/bash

source ~/.bash_profile

# Ensure the API key is set
if [ -z "$NEWRELIC_API_KEY" ]; then
    echo "NEWRELIC_API_KEY is not set"
    exit 0
fi

# API request to get throughput and response time
response=$(curl -s -X 'GET' 'https://api.newrelic.com/v2/applications/19813715.json' -H 'accept: application/json' -H "x-api-key: $NEWRELIC_API_KEY")

# Parse the response to get throughput and response time
throughput=$(echo $response | jq -r '.application.application_summary.throughput')
response_time=$(echo $response | jq -r '.application.application_summary.response_time')

# Remove trailing .0 from throughput if present
formatted_throughput=$(awk '{printf "%.0f\n", $0}' <<< "$throughput")

# Display response time and throughput in the menu bar
echo "${response_time}ms / ${formatted_throughput}rpm"
