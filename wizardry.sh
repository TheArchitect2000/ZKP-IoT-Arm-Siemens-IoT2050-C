#!/bin/bash

total_steps=8

echo "What would you like to do?"
echo "1. Install Device"
echo "2. Generate Commitment"
echo "3. Generate ZKP"
read -p "Enter your choice (1, 2, or 3): " user_choice


case $user_choice in
    1)
        ./install_device
        ;;
    
    2)
    
        # Step 1: Compile the program.cpp to assembly
        echo "[1/$total_steps] Compiling program.cpp to assembly"
        g++ -std=c++17 -S program.cpp -o program.s -lstdc++ -lmosquitto -lpthread
        if [ $? -ne 0 ]; then
            echo "Compilation failed"
            exit 1
        fi

        # Step 2: Find the line number that uses 'mul' after '#APP' in program.s
        echo "[2/$total_steps] Finding the first instruction after '#APP' in program.s"
        line_number=$(awk '/#APP/{flag=1; next} flag && /add|mul/{print NR; exit}' program.s)
        if [ -z "$line_number" ]; then
            echo "No relevent instruction found after '#APP'"
            exit 1
        fi

        # Step 3: Read the class value from device_config.json
        echo "[3/$total_steps] Reading class value from device_config.json"
        config_file="device_config.json"
        class_value=$(jq -r '.class' "$config_file")
        if [ -z "$class_value" ]; then
            echo "Class value not found in device_config.json"
            exit 1
        fi

        # Step 4: Read n_g from class.json based on the class value
        echo "[4/$total_steps] Reading relevant info from class.json based on class value"
        class_file="class.json"
        n_g=$(jq --arg class_value "$class_value" '.[$class_value].n_g' "$class_file")
        if [ -z "$n_g" ]; then
            echo "n_g not found for class $class_value in class.json"
            exit 1
        fi

        # Step 5: Calculate the new values for code_block
        echo "[5/$total_steps] Calculating new values for code_block"
        second_value=$((line_number + n_g -1))

        # Step 6: Update device_config.json with the new values
        echo "[6/$total_steps] Updating device_config.json 'code_block' with new values"
        temp_file=$(mktemp)
        jq --argjson line_number "$line_number" --argjson second_value "$second_value" '.code_block = [$line_number, $second_value]' "$config_file" > "$temp_file" && mv "$temp_file" "$config_file"

        # Step 7: Run the commitmentGenerator and store the output logs
        echo "[7/$total_steps] Running commitmentGenerator"
        log_dir="log"
        if [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir"
        fi
        ./commitmentGenerator > log/commitmentGenerator.log 2>&1
        if [ $? -ne 0 ]; then
            echo "commitmentGenerator execution failed"
            exit 1
        fi

        # Step 8: Build the program_new.s using the updated codes and store the output logs
        echo "[8/$total_steps] Build the executable from program_new.s"
        g++ -std=c++17 program_new.s lib/polynomial.cpp -o program -lstdc++ -lmosquitto -lpthread
        if [ $? -ne 0 ]; then
            echo "Build failed"
            exit 1
        fi

        ;;
    3)
        # Step 9: Execute the program and store the output logs
        # echo "[9/$total_steps] Executing program"
        # ./program > log/proofGeneration.log 2>&1
        echo "Generating ZKP."
        while true; do
            ./program 2>&1  # Redirect both stdout and stderr to /dev/null
            if [ $? -eq 0 ]; then
                break  # Exit the loop if the program exits successfully
            else
                echo "Restarting Program..."
            fi
        done
        ;;
esac
# Step 10: Run the verifier and store the output logs
# echo "[10/$total_steps] Running the verifier"
# ./verifier > log/verifier.log 2>&1
# if [ $? -ne 0 ]; then
#     echo "Verifier execution failed"
#     exit 1
# fi

# Step 11: Check verifier.log for verification result
# echo "[11/$total_steps] Checking verification result"
# if grep -q 'verify!' log/verifier.log; then
#     echo "Verification: true"
# else
#     echo "Verification: false"
# fi

# echo "Script completed successfully"
