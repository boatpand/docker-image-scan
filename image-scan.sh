#!/bin/bash

filename="list.txt"

timestamp=$(date +%d%m%Y-%H%M%S)
mkdir ~/Desktop/result-image-scan-$timestamp
mkdir ~/Desktop/result-image-scan-$timestamp/os && mkdir ~/Desktop/result-image-scan-$timestamp/dependencies
cd ~/Desktop/result-image-scan-$timestamp
touch report-image-os-$timestamp.csv && touch report-image-dependencies-$timestamp.csv
echo "name,version,cri,high,medium,low" > report-image-os-$timestamp.csv && echo "name,version,cri,high,medium,low" > report-image-dependencies-$timestamp.csv
cd -

# for loop list file
while IFS=":" read -r image tag || [ -n "$image" ]
do
    # docker pull $image:$tag
    echo $image 
    os_result="$image""-os"
    dependencies_result="$image""-dependencies"

    snyk container test $image:$tag --json > "snyk_$image.json"
    trivy image --format template --template "@./html.tpl" -o "trivy_$image.html" $image:$tag

    # Dependencies
    jq '.applications' "snyk_$image.json" > "$dependencies_result"".json"
    dependencies=$(cat "$dependencies_result"".json")
    if [[ "$dependencies" != "null" ]]; then
        snyk-to-html -i "$dependencies_result"".json" -o "$dependencies_result"".html"
        critical_dependencies_count=$(grep -o "critical severity" "$dependencies_result"".html" | wc -l)
        high_dependencies_count=$(grep -o "high severity" "$dependencies_result"".html" | wc -l)
        medium_dependencies_count=$(grep -o "medium severity" "$dependencies_result"".html" | wc -l)
        low_dependencies_count=$(grep -o "low severity" "$dependencies_result"".html" | wc -l)
    else
        critical_dependencies_count="0"
        high_dependencies_count="0"
        medium_dependencies_count="0"
        low_dependencies_count="0"
    fi
    
    start_dependencies=$(grep -n "class=\"group-header\"" report.html | awk -F ':' 'NR==2 {print $1}')
    end_dependencies=$(grep -n "/table" report.html | awk -F ':' '{print $1-1}')
    sed "${start_dependencies},${end_dependencies}d" "trivy_$image.html" > "$os_result"".html"

    critical_os_count=$(grep -o "class=\"severity\".CRITICAL" "$os_result"".html" | wc -l)
    high_os_count=$(grep -o "class=\"severity\".HIGH" "$os_result"".html" | wc -l)
    medium_os_count=$(grep -o "class=\"severity\".MEDIUM" "$os_result"".html" | wc -l)
    low_os_count=$(grep -o "class=\"severity\".LOW" "$os_result"".html" | wc -l)

    cd ~/Desktop/result-image-scan-$timestamp
    echo "$image,$tag,$critical_os_count,$high_os_count,$medium_os_count,$low_os_count" >> report-image-os-$timestamp.csv
    echo "$image,$tag,$critical_dependencies_count,$high_dependencies_count,$medium_dependencies_count,$low_dependencies_count" >> report-image-dependencies-$timestamp.csv
    cd -
    mv *-os.html ~/Desktop/result-image-scan-$timestamp/os && mv *-dependencies.html ~/Desktop/result-image-scan-$timestamp/dependencies

    rm *.json
    # docker image rm $image:$tag
done < "$filename"