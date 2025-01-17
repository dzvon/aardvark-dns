#!/usr/bin/env bats   -*- bats -*-
#
# basic netavark tests
#

load helpers

@test "basic container - dns itself" {
	setup_slirp4netns

	subnet_a=$(random_subnet 5)
	create_config "podman1" $(random_string 64) "aone" "$subnet_a" "a1" "1a"
	config_a1=$config
	ip_a1=$(echo "$config_a1" | jq -r .networks.podman1.static_ips[0])
	gw=$(echo "$config_a1" | jq -r .network_info.podman1.subnets[0].gateway)
	create_container "$config_a1"
	a1_pid=$CONTAINER_NS_PID
	run_in_container_netns "$a1_pid" "dig" "+short" "aone" "@$gw"
	assert "$ip_a1"

	run_in_container_netns "$a1_pid" "dig" "+short" "google.com" "@$gw"
	# validate that we get an ipv4
	assert "$output" =~ "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
}

@test "basic container - dns itself with long network name" {
	subnet_a=$(random_subnet 5)
	long_name="podman11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
	create_config "$long_name" $(random_string 64) "aone" "$subnet_a" "a1" "1a"
	config_a1=$config
	ip_a1=$(echo "$config_a1" | jq -r .networks.$long_name.static_ips[0])
	gw=$(echo "$config_a1" | jq -r .network_info.$long_name.subnets[0].gateway)
	create_container "$config_a1"
	a1_pid=$CONTAINER_NS_PID
	run_in_container_netns "$a1_pid" "dig" "+short" "aone" "@$gw"
	assert "$ip_a1"
}

@test "two containers on the same network" {
	# container a1
	subnet_a=$(random_subnet 5)
	create_config "podman1" $(random_string 64) "aone" "$subnet_a" "a1" "1a"
	config_a1="$config"
	a1_ip=$(echo "$config_a1" | jq -r .networks.podman1.static_ips[0])
	gw=$(echo "$config_a1" | jq -r .network_info.podman1.subnets[0].gateway)
	create_container "$config_a1"
	a1_pid=$CONTAINER_NS_PID

	# container a2
	create_config "podman1" $(random_string 64) "atwo" "$subnet_a" "a2" "2a"
	config_a2="$config"
	a2_ip=$(echo "$config_a2" | jq -r .networks.podman1.static_ips[0])
	create_container "$config_a2"
	a2_pid="$CONTAINER_NS_PID"

	# Resolve container names to IPs
	dig "$a1_pid" "atwo" "$gw"
	assert "$a2_ip"
	dig "$a2_pid" "aone" "$gw"
	assert "$a1_ip"
}
