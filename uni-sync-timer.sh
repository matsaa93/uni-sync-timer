#!/bin/bash
config_file=/etc/uni-sync/uni-sync.json 
config_file_mem="$(cat $config_file)"
profile_json=/etc/uni-sync/uni-sync_profile.json
profile_json_mem="$(cat $profile_json)"
declare -a sensor_file
declare -a channel
declare -a profile_name
declare -A profile_temp
declare -A profile_speed

set_json_variable(){
    # Usage: 
    #       set_json_variable $file_string $Variable_value $JSON_PATH
    local File=$1; local VAR=$2; local JPath=$3
    echo "$File" | jq --arg variable "$VAR" "$JPath = $VAR"
}
set_fan_speed(){
    # Usage: 
    #       set_fan_speed $config_int $channel_int $speed_int
    local config=$1; local channels=$2; local speed=$3
    set_json_variable "$config_file_mem" $speed ".configs[$config].channels[$channels].speed"
}
#set_fan_speed 0 0 30
get_json_variable(){
    echo "$profile_json_mem" | jq -r ".configs[$1].$2"
}
#get_json_variable 1 driver
find_sensor_file(){
    for d in $(ls /dev/$1/*_label); do
        [ "$(cat $d)" == $2 ] && echo "${d/label/input}"
    done
}
get_json_item_count(){
    # Usage:
    #       get_json_item_count "$FILE_STRING" "$JSON_PATH"
    local File=$1
    local JPath=$2
    echo $(($(echo "$File" | jq "$JPath | length") - 1))
}
#get_json_item_count "$profile_json_mem" ".[]"

load_profile_to_mem(){
    echo "Loading Fan Profile to Memory"
    #channel=$(get_json_variable "" channel)
    local f
    for d in $(seq 0 $(get_json_item_count "$profile_json_mem" ".[]")); do
        printf "\nLoading config: $d"
        profile_name[$d]="$(get_json_variable $d name)"
        printf "\n\tprofile Name: ${profile_name[$d]}"
        sensor_file[${d}]="$(find_sensor_file "$(get_json_variable $d driver)" "$(get_json_variable $d sensor)")"
        printf "\n\tsensor file: ${sensor_file[$d]}"
        channel[$d]="$(get_json_variable $d channel)"
        printf "\n\tchannel: ${channel[$d]}"
        printf "\n\tSetpoints:"
        for g in $(seq 0 $(get_json_item_count "$profile_json_mem" ".configs[$d].profile")); do
            printf "\n\t\tsetpoint: $g"
            profile_temp[$d,$g]="$(get_json_variable $d profile[$g].temp)"
            profile_speed[$d,$g]="$(get_json_variable $d profile[$g].speed)"
            printf "\n\t\t\t Temperature: ${profile_temp[$d,$g]} Speed: ${profile_speed[$d,$g]}"
        done
    done
    echo ""
}

get_sensor_info(){
     cat $1
}

calculate_speed(){
    # Usage:
    #       calculate_speed "$TEMPERATURE" "$CONFIG"
    local delta_t; local delta_v; local vtmp; local ctmp
    local temp=$1; local config=$2
    local f=$(get_json_item_count "$profile_json_mem" ".configs[$d].profile")
    #local profile=$3
    if [[ $temp -lt ${profile_temp[$config,0]} ]]; then
        echo "${profile_speed[$config,0]}"
    elif [[ $temp -gt ${profile_temp[$config,$f]} ]]; then
        echo "${profile_speed[$config,$f]}"
    else
        for t in $(seq 0 $f); do
            #echo "${profile_temp[$config,$t]}"
            if [[ ${profile_temp[$config,$t]} -eq $temp ]]; then
                echo "${profile_speed[$config,$t]}"
                break
            elif [[ $temp -gt ${profile_temp[$config,$t]} && $temp -lt ${profile_temp[$config,$(($t + 1))]} ]]; then
                #echo "is between to profile temps"
                delta_t="$((${profile_temp[$config,$(($t + 1))]} - ${profile_temp[$config,$t]}))"
                delta_v="$((${profile_speed[$config,$(($t + 1))]} - ${profile_speed[$config,$t]}))"
                #vtmp="$((($delta_v / $delta_t) * ($temp - ${profile_temp[$config,$t]})))"
                vtmp="$(echo "$delta_v/$delta_t" | bc -l)"
                #echo "$vtmp"
                ctmp="$(($temp - ${profile_temp[$config,$t]}))"
                #echo "$ctmp"
                vtmp="$(bc <<< $vtmp*$ctmp)"
                vtmp="$(echo "($vtmp+0.5)/1" | bc )"
                #echo "$vtmp"
                #echo "${profile_speed[$config,$t]}"
                vtmp="$((${vtmp} + ${profile_speed[$config,$t]}))"
                echo "$vtmp"
                break
            fi
        done
    fi
}
#calculate_speed 49 0 
Check_temp_set_speed_loop(){
    local vtmp
    for t in $(seq 0 $(get_json_item_count "$profile_json_mem" ".[]")); do
        vtmp=$(calculate_speed $(echo "$(cat ${sensor_file[$t]})/1000" | bc) $t)
        config_file_mem="$(set_fan_speed 0 $t $vtmp)"
    done
    echo "$config_file_mem"
}

load_profile_to_mem
while [ true ]; do
    Check_temp_set_speed_loop > $config_file
    uni-sync $config_file
    sleep 15
done