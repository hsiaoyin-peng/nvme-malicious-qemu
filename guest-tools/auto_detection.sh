et -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_times="${RUN_TIMES:-100}"
max_time=0
min_time=999999
total_time=0

report_capacity="${REPORT_CAPACITY_GB:-2}"
capacity_probes="${CAPACITY_PROBES:-8}"
target_dev="${TARGET_DEV:-/dev/nvme0n1}"

count_cap_not_detect=0
count_cap_suspicious=0

echo "========= Fake Capacity Detection Start ========="
echo "Target Device: $target_dev"
echo "Report Capacity: $report_capacity GiB"
echo "Capacity Probes: $capacity_probes times"
echo "Run Times: $run_times"
echo "================================================"

for i in $(seq "$run_times")
do
    result=$(python3 "$SCRIPT_DIR/nvme_attack_detector.py" \
        --dev "$target_dev" \
        --test capacity \
        --reported-size-gb "$report_capacity" \
        --capacity-probes "$capacity_probes" \
        --yes)

    detection_time=$(echo "$result" | grep -oE 'Elapsed: [0-9]+\.[0-9]+s' | grep -oE '[0-9.]+')
    status=$(echo "$result" | grep "Fake capacity/high-LBA integrity:" | tail -n 1 | cut -d ':' -f 2 | xargs)

    echo "Run $i : $detection_time second  Status: $status"

    if [[ "$status" == "not detected" ]]; then
        count_cap_not_detect=$((count_cap_not_detect + 1))
    elif [[ "$status" == "SUSPICIOUS" ]]; then
        count_cap_suspicious=$((count_cap_suspicious + 1))
    fi

    if [[ "$(echo "$detection_time > $max_time" | bc -l)" -eq 1 ]]; then
        max_time=$detection_time
    fi

    if [[ "$(echo "$detection_time < $min_time" | bc -l)" -eq 1 ]]; then
        min_time=$detection_time
    fi

    total_time=$(echo "$total_time + $detection_time" | bc -l)
done

avg_time=$(echo "scale=4; $total_time / $run_times" | bc -l)

echo "-------------- Result --------------"
echo "Execution Times: $run_times"
echo "Max Execution Time: $max_time second"
echo "Min Execution Time: $min_time second"
echo "Total Execution Time: $total_time second"
echo "Average Execution Time: $avg_time second"
echo "Detection Result(Suspicious/Normal): $count_cap_suspicious / $count_cap_not_detect"
echo "------------------------------------"
