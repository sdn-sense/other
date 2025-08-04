#!/bin/bash

# Configuration
KUBECONFIG_PATH="/Users/jbalcas/.kube/config-ucsd"
NAMESPACE="osg-gil"
POD_FILTER="sdsc-origin-111"

get_pods() {
    kubectl get pods --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" | \
    grep "$POD_FILTER" | grep Running | awk '{print $1}'
}

create_server_script() {
    local script_path="$1"
    cat > "$script_path" << EOF
#!/bin/bash
echo "[\$(date)] Starting FDT server setup on \$(hostname)..."
echo "[\$(date)] Installing dependencies..."
yum install java wget -y

echo "[\$(date)] Downloading FDT jar..."
wget --no-check-certificate https://monalisa.cern.ch/FDT/lib/fdt.jar

echo "[\$(date)] Starting FDT server..."
java -jar fdt.jar
EOF
    chmod +x "$script_path"
}

setup_server_on_pod() {
    local pod_name="$1"
    
    echo "[$pod_name] Setting up FDT server..."
    
    # Create unique script file for this pod
    local script_file="/tmp/fdt_server_${pod_name}.sh"
    create_server_script "$script_file"
    
    echo "[$pod_name] Copying server script..."
    kubectl cp "$script_file" "$NAMESPACE/$pod_name:/tmp/fdt_server.sh" --kubeconfig "$KUBECONFIG_PATH"
    
    echo "[$pod_name] Starting FDT server..."
    kubectl exec "$pod_name" --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" -- \
        /bin/bash /tmp/fdt_server.sh 2>&1 | \
    while IFS= read -r line; do
        echo "[$pod_name] $line"
    done
    
    rm -f "$script_file"
}

main() {
    echo "Getting list of running server pods..."
    pods=($(get_pods))
    
    if [ ${#pods[@]} -eq 0 ]; then
        echo "No running pods found matching criteria"
        exit 1
    fi
    
    echo "Found ${#pods[@]} server pods:"
    printf '%s\n' "${pods[@]}"
    echo "----------------------------------------"
    echo "Starting FDT servers on all pods..."
    
    pids=()
    
    for pod in "${pods[@]}"; do
        echo "Starting FDT server setup on $pod"
        setup_server_on_pod "$pod" &
        pids+=($!)
    done
    
    echo "All FDT server setups started in parallel..."
    echo "----------------------------------------"
    
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    echo "----------------------------------------"
    echo "All FDT servers started successfully!"
}

cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/fdt_server_*.sh
}

trap cleanup EXIT

main "$@"

