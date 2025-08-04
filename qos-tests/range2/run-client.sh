#!/bin/bash

# Configuration
KUBECONFIG_PATH="/Users/jbalcas/.kube/config-tier2"
NAMESPACE="sense"
POD_FILTER="xrootd-origin-02"

# IPv6 addresses for FDT commands
IPV6_ADDRESSES=(
    "2001:48d0:3001:112::400"
    "2001:48d0:3001:112::500"
    "2001:48d0:3001:112::600"
    "2001:48d0:3001:112::700"
    "2001:48d0:3001:112::400"
    "2001:48d0:3001:112::500"
    "2001:48d0:3001:112::600"
)

get_pods() {
    kubectl get pods --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" | \
    grep "$POD_FILTER" | grep Running | awk '{print $1}'
}

create_setup_script() {
    local ipv6_addr="$1"
    local script_path="$2"
    cat > "$script_path" << EOF
#!/bin/bash
echo "[\$(date)] Starting setup on \$(hostname)..."
echo "[\$(date)] Installing dependencies..."
yum install java wget iproute -y

echo "[\$(date)] Downloading FDT jar..."
wget --no-check-certificate https://monalisa.cern.ch/FDT/lib/fdt.jar

echo "[\$(date)] Running FDT test to $ipv6_addr..."
java -jar fdt.jar -c $ipv6_addr -nettest -P 4

echo "[\$(date)] FDT test completed on \$(hostname)"
EOF
    chmod +x "$script_path"
}

deploy_to_pod() {
    local pod_name="$1"
    local ipv6_addr="$2"
    
    local script_file="/tmp/fdt_setup_${pod_name}.sh"
    create_setup_script "$ipv6_addr" "$script_file"
    
    kubectl cp "$script_file" "$NAMESPACE/$pod_name:/tmp/fdt_setup.sh" --kubeconfig "$KUBECONFIG_PATH" 2>/dev/null
    
    kubectl exec "$pod_name" --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" -- /bin/bash /tmp/fdt_setup.sh 2>&1 | \
    while IFS= read -r line; do
        echo "[$pod_name] $line"
    done
    
    rm -f "$script_file"
}

main() {
    echo "Getting list of running pods..."
    pods=($(get_pods))
    
    if [ ${#pods[@]} -eq 0 ]; then
        echo "No running pods found matching criteria"
        exit 1
    fi
    
    echo "Found ${#pods[@]} pods:"
    printf '%s\n' "${pods[@]}"
    echo "----------------------------------------"
    echo "Starting parallel deployment to all pods..."
    
    pids=()
    
    for i in "${!pods[@]}"; do
        if [ $i -lt ${#IPV6_ADDRESSES[@]} ]; then
            ipv6_addr="${IPV6_ADDRESSES[$i]}"
        else
            addr_index=$((i % ${#IPV6_ADDRESSES[@]}))
            ipv6_addr="${IPV6_ADDRESSES[$addr_index]}"
        fi
        
        echo "Starting deployment to ${pods[$i]} with IPv6: $ipv6_addr"
        
        deploy_to_pod "${pods[$i]}" "$ipv6_addr" &
        pids+=($!)
    done
    
    echo "All deployments started in parallel..."
    echo "----------------------------------------"
    
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    echo "----------------------------------------"
    echo "All pods processed successfully!"
}

main "$@"

