#!/bin/bash

filename="list.txt"
pattern='"vulnerabilities":'

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
    # docker scan $image:$tag --json > $image.json
    snyk container test $image:$tag --json > $image.json
    all_result="$image"
    os_result="$image""-os"
    dependencies_result="$image""-dependencies"

    # OS 
    jq 'del(.applications)' "$all_result"".json" > "$os_result"".json"

    # Dependencies
    jq '.applications' "$all_result"".json" > "$dependencies_result"".json"

    snyk-to-html -i "$os_result"".json" -o "$os_result"".html"
    snyk-to-html -i "$dependencies_result"".json" -o "$dependencies_result"".html"

    critical_os_count=$(grep -o "critical severity" "$os_result"".html" | wc -l)
    high_os_count=$(grep -o "high severity" "$os_result"".html" | wc -l)
    medium_os_count=$(grep -o "medium severity" "$os_result"".html" | wc -l)
    low_os_count=$(grep -o "low severity" "$os_result"".html" | wc -l)

    critical_dependencies_count=$(grep -o "critical severity" "$dependencies_result"".html" | wc -l)
    high_dependencies_count=$(grep -o "high severity" "$dependencies_result"".html" | wc -l)
    medium_dependencies_count=$(grep -o "medium severity" "$dependencies_result"".html" | wc -l)
    low_dependencies_count=$(grep -o "low severity" "$dependencies_result"".html" | wc -l)

    cd ~/Desktop/result-image-scan-$timestamp
    echo "$image,$tag,$critical_os_count,$high_os_count,$medium_os_count,$low_os_count" >> report-image-os-$timestamp.csv
    echo "$image,$tag,$critical_dependencies_count,$high_dependencies_count,$medium_dependencies_count,$low_dependencies_count" >> report-image-dependencies-$timestamp.csv
    
    cd -
    mv *-os.html ~/Desktop/result-image-scan-$timestamp/os && mv *-dependencies.html ~/Desktop/result-image-scan-$timestamp/dependencies

    rm *.json
    # docker image rm $image:$tag
done < "$filename"
