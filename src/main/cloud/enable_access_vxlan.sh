
rancher_env=env_k8s_vxlan_internal

#rancher --env ${rancher_env} ps -a -s -c
#rancher --env ${rancher_env} stacks ls -s

vxlan_containers=$(rancher --env ${rancher_env} ps -a -s -c | grep vxlan | grep -v driver | awk '{print "id:"$1",host_id:"$5",container_ip:"$6",container_id:"$7}')
for container in ${vxlan_containers[@]}; do
    id=$(echo ${container} | awk -F, '{print $1}' | awk -F: '{print $2}')
    host_id=$(echo ${container} | awk -F, '{print $2}' | awk -F: '{print $2}')
    container_ip=$(echo ${container} | awk -F, '{print $3}' | awk -F: '{print $2}')
    container_id=$(echo ${container} | awk -F, '{print $4}' | awk -F: '{print $2}')
    host_ip=$(rancher --env ${rancher_env} hosts | grep ${host_id} | awk '{print $5}')
    
    # need a rule like this 'MASQUERADE  all  --  anywhere             anywhere' in 'Chain POSTROUTING (policy ACCEPT)'
    rule_found=$(rancher --env ${rancher_env} exec ${id} iptables -t nat --list | grep -E "(MASQUERADE)[ ]+(all)[ ]+(.+)[ ]+(anywhere)[ ]+(anywhere)")
    if [ -z "${rule_found}" ]; then
        rancher --env ${rancher_env} exec ${id} iptables -t nat -A POSTROUTING -j MASQUERADE
        rancher --env ${rancher_env} exec ${id} iptables -t nat --list
    else
        echo "rule '${rule_found}' found"
    fi
    echo "run 'sudo route -n add -net 10.42.0.0/16 ${host_ip}' on mac to add route table entry."
    echo "then 'ping ${container_ip}' to test VXLAN access."
done
