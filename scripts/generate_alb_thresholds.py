import time
import json
import argparse
from datadog import initialize, api

# Initialize Datadog client
options = {
    "api_key": API_KEY,
    "app_key": APP_KEY
}
initialize(**options)

END_TIME = int(time.time())
START_TIME = END_TIME - 3 * 30 * 24 * 3600

QUERIES = {
    "request_count": "avg:aws.applicationelb.request_count{loadbalancer:%s}.as_rate()",
    "latency": "avg:aws.applicationelb.target_response_time.average{loadbalancer:%s}",
    "error_rate": (
        "sum:aws.applicationelb.httpcode_target_5xx{loadbalancer:%s}.as_count() / "
        "sum:aws.applicationelb.request_count{loadbalancer:%s}.as_count() * 100"
    )
}

MULTIPLIERS = {
    "request_count": {"critical": 1.0, "critical_recovery": 0.8, "warning": 0.9, "warning_recovery": 0.7},
    "latency": {"critical": 1.0, "critical_recovery": 0.8, "warning": 0.9, "warning_recovery": 0.7},
    "error_rate": {"critical": 1.0, "critical_recovery": 0.6, "warning": 0.8, "warning_recovery": 0.5},
}


def fetch_historical_data(query, start_time, end_time):
    try:
        result = api.Metric.query(start=start_time, end=end_time, query=query)
        if 'series' not in result or not result['series']:
            print(f"No data found for query: {query}")
            return None

        data_points = result['series'][0]['pointlist']
        values = [point[1] for point in data_points if point[1] is not None]
        return sum(values) / len(values) if values else None

    except Exception as e:
        print(f"Error fetching data for query '{query}': {e}")
        return None


def calculate_thresholds(avg_value, multipliers):
    if avg_value is None:
        return {
            "critical": multipliers.get("default_critical", 1),
            "critical_recovery": multipliers.get("default_critical_recovery", 0.8),
            "warning": multipliers.get("default_warning", 0.9),
            "warning_recovery": multipliers.get("default_warning_recovery", 0.7)
        }
    return {
        "critical": avg_value * multipliers["critical"],
        "critical_recovery": avg_value * multipliers["critical_recovery"],
        "warning": avg_value * multipliers["warning"],
        "warning_recovery": avg_value * multipliers["warning_recovery"]
    }


def process_alb_monitoring(env, alb):
    thresholds = {}

    for monitor, query_template in QUERIES.items():
        if monitor == "error_rate":
            query = query_template % (alb, alb)
        else:
            query = query_template % alb

        print(f"Processing monitor: {monitor}, Environment: {env}, ALB: {alb}")
        avg_value = fetch_historical_data(query, START_TIME, END_TIME)
        if avg_value is not None:
            print(f"Average value for {monitor} ({alb}): {avg_value}")
        else:
            print(f"No data found for {monitor} ({alb})")

        thresholds[monitor] = calculate_thresholds(avg_value, MULTIPLIERS[monitor])

    return thresholds


def main():
    parser = argparse.ArgumentParser(description="Generate historical thresholds for ALB monitors.")
    parser.add_argument("--env", required=True, help="Environment name (e.g., qa, staging, prd).")
    parser.add_argument("--alb", required=True, help="ALB name (e.g., qa-alb-1).")
    args = parser.parse_args()

    # Sanitize ALB name for file output
    sanitized_alb_name = args.alb.replace("/", "_")
    thresholds = process_alb_monitoring(args.env, args.alb)

    # Save thresholds to JSON
    output_file = f"alb_thresholds_{args.env}_{sanitized_alb_name}.json"
    with open(output_file, "w") as f:
        json.dump(thresholds, f, indent=2)

    print(f"Thresholds saved to {output_file}")


if __name__ == "__main__":
    main()
