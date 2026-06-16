#!/usr/bin/env bash

cd ./OmuStation/Content.MapRenderer
mapyaml="../Resources/Prototypes/Maps/Pools/default.yml"
outputpath="/tmp/output"

processedMaps=()
while IFS= read -r map; do
    map="${map//\"/}"
    processedMaps+=("$map")

    echo "Processing map: $map"

    (
        dotnet run --format webp -m --parallax --viewer -o "$outputpath" "$map"

        mv "$outputpath/$map/map.json" "$outputpath/$map/map.backup.json"
        jq 'walk(if type == "object" then with_entries(.key |= (.[0:1] | ascii_downcase) + .[1:] | if .key == "extent" and (.value | type) == "object" then .value = {a: {x: .value.x1, y: .value.y1}, b: {x: .value.x2, y: .value.y2}} elif .key == "url" and (.value | type) == "string" then .value |= "maps/" + . else . end) else . end)' "$outputpath/$map/map.backup.json" > "$outputpath/$map/map.json"
    ) &
    
    if (( $(jobs -r -p | wc -l) >= 16 )); then
        wait -n
    fi
done < <(yq '.[] | select(.id == "DefaultMapPool") | .maps[]' "$mapyaml")

wait

mkdir "$outputpath/maps/"
printf '%s\n' "${processedMaps[@]}" | jq -R . | jq -s 'map({name: ., id: .}) | {maps: .}' > "$outputpath/maps/maps.json"
