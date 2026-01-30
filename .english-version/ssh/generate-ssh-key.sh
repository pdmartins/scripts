#!/bin/bash

# ANSI Colors
YELLOW='\033[33m'
CYAN='\033[36m'
WHITE='\033[37m'
GRAY='\033[90m'
GREEN='\033[32m'
RED='\033[31m'
RESET='\033[0m'

# Function to verify and handle existing keys
resolve_existing_key() {
    local key_name="$1"
    local ssh_directory="$2"
    
    # Remove "id_" prefix if user typed it
    if [[ "$key_name" == id_* ]]; then
        key_name="${key_name:3}"
    fi
    
    local key_path="$ssh_directory/id_$key_name"
    
    # If key doesn't exist, return the name
    if [[ ! -f "$key_path" ]]; then
        echo "$key_name"
        return
    fi
    
    # Key exists - display information
    echo -e "\n${YELLOW}⚠️  The key '$key_path' already exists!${RESET}"
    
    # Display existing public key content
    local public_key_path="$key_path.pub"
    if [[ -f "$public_key_path" ]]; then
        echo -e "\n${CYAN}📄 Existing public key content:${RESET}"
        echo -e "${WHITE}$(cat "$public_key_path")${RESET}"
    fi
    
    echo -e "\n${GRAY}🤔 What would you like to do?${RESET}"
    echo -e "${GRAY}  ↩️ ENTER - Overwrite existing file${RESET}"
    echo -e "${GRAY}  ✏️ Type a new name - Generate with another name${RESET}"
    echo -e "${GRAY}  ⛔ Type 'exit' or press Ctrl+C to cancel${RESET}"
    
    # Capture input
    echo -en "\n${GRAY}👉 Type: ${RESET}"
    read -r response
    
    if [[ -z "$response" ]]; then
        # ENTER pressed - overwrite
        echo -e "\n${YELLOW}🔄 Overwriting existing file...${RESET}"
        echo "$key_name"
        return
    fi
    
    # Convert to lowercase
    local response_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response_lower" == "exit" ]] || [[ "$response_lower" == "e" ]] || [[ "$response_lower" == "quit" ]]; then
        # "exit" typed
        echo -e "\n${RED}❌ Operation cancelled.${RESET}"
        exit 0
    else
        # New name typed - verify recursively
        resolve_existing_key "$response" "$ssh_directory"
    fi
}

# Parameters
email="$1"
name="$2"

# If email was not provided, request it
if [[ -z "$email" ]]; then
    echo -n "📧 Enter email: "
    read -r email
fi

# Extract email prefix
email_prefix="${email%%@*}"

# If name was not provided, request it
if [[ -z "$name" ]]; then
    echo -en "${GRAY}🔑 Enter key name (leave blank to use ${RESET}"
    echo -en "${YELLOW}$email_prefix${RESET}"
    echo -en "${GRAY}): ${RESET}"
    read -r name
fi

# If name is blank, use email prefix
if [[ -z "$name" ]]; then
    name="$email_prefix"
    echo -e "${GRAY}✨ Using '${RESET}${YELLOW}$email_prefix${RESET}${GRAY}' as key name (extracted from email)${RESET}"
fi

# Remove "id_" prefix if user typed it
if [[ "$name" == id_* ]]; then
    name="${name:3}"
    echo -e "${YELLOW}📌 Removed duplicate 'id_' prefix. Using: $name${RESET}"
fi

# Build complete file path (always in ~/.ssh)
ssh_dir="$HOME/.ssh"
if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    echo -e "${GREEN}📁 .ssh directory created at: $ssh_dir${RESET}"
fi

# Verify and resolve key name (handling duplicates)
name=$(resolve_existing_key "$name" "$ssh_dir")
key_path="$ssh_dir/id_$name"

echo -e "\n${CYAN}🔐 Generating SSH key id_$name${RESET}"
echo -e "${WHITE}📝 ssh-keygen -t ed25519 -C \"$email\" -f \"$key_path\" -N \"\"\n${RESET}"

# Execute ssh-keygen (with empty passphrase and overwrite without asking)
yes y 2>/dev/null | ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""

# Verify if key was generated successfully
if [[ $? -eq 0 ]]; then
    echo -e "\n${GREEN}=================================${RESET}"
    echo -e "${GREEN}✅ SSH key generated successfully!${RESET}"
    echo -e "${GREEN}=================================${RESET}"
    
    # Display public key content
    public_key_path="$key_path.pub"
    
    if [[ -f "$public_key_path" ]]; then
        echo -e "\n${CYAN}📋 Public key content (copy the text below):${RESET}"
        echo -e "${WHITE}$(cat "$public_key_path")${RESET}"
    else
        echo -e "\n${RED}⚠️  Warning: Could not find public key file at: $public_key_path${RESET}"
    fi
else
    echo -e "\n${RED}❌ Error generating SSH key!${RESET}"
fi
