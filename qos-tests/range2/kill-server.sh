#!/bin/bash

# Configuration
KUBECONFIG_PATH="/Users/jbalcas/.kube/config-ucsd"
NAMESPACE="osg-gil"
POD_FILTER="sdsc-origin-112"

get_pods() {
    kubectl get pods --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" | \
    grep "$POD_FILTER" | grep Running | awk '{print $1}'
}

kill_java_on_pod() {
    local pod_name="$1"
    
    echo "[$pod_name] Checking Java processes..."
    java_processes=$(kubectl exec "$pod_name" --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" -- \
        ps aux | grep java | grep -v grep 2>/dev/null)
    
    if [ -n "$java_processes" ]; then
        echo "[$pod_name] Found Java processes:"
        echo "$java_processes"
        echo "[$pod_name] Killing Java processes..."
        kubectl exec "$pod_name" --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" -- \
            pkill -9 -f java 2>/dev/null
        echo "[$pod_name] Java processes killed"
    else
        echo "[$pod_name] No Java processes found"
    fi
    echo "----------------------------------------"
}

main() {
    echo "Getting list of running server pods..."
    pods=($(get_pods))
    
    if [ ${#pods[@]} -eq 0 ]; then
        echo "No running pods found"
        exit 1
    fi
    
    echo "Found ${#pods[@]} server pods - checking and killing Java processes..."
    echo "----------------------------------------"
    
    for pod in "${pods[@]}"; do
        kill_java_on_pod "$pod"
    done
    
    echo "All Java processes killed on server pods!"
}

main "$@"

