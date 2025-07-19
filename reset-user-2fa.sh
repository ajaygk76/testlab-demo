#!/bin/bash

# Azure User 2FA Reset Script
# Usage: ./reset-user-2fa.sh <user_email> <group_name> [--force]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <user_email> <group_name> [--force]"
    echo ""
    echo "Examples:"
    echo "  $0 hemanth.kumar2@sony.com gisc-in"
    echo "  $0 hemanth.kumar2@sony.com gisc-in --force"
    echo ""
    echo "Options:"
    echo "  --force    Perform actual 2FA reset (default is dry run)"
    exit 1
fi

USER_EMAIL="$1"
GROUP_NAME="$2"
FORCE_RESET=false

# Check for --force flag
if [ "$3" = "--force" ]; then
    FORCE_RESET=true
    print_warning "Force reset mode enabled - this will actually reset the user's 2FA!"
fi

print_status "Starting 2FA reset process for user: $USER_EMAIL in group: $GROUP_NAME"

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    print_error "Ansible is not installed. Please install Ansible first."
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install Azure CLI first."
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if required environment variables are set
REQUIRED_VARS=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "AZURE_CLIENT_ID" "AZURE_CLIENT_SECRET")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please set these variables:"
    echo "export AZURE_SUBSCRIPTION_ID='your-subscription-id'"
    echo "export AZURE_TENANT_ID='your-tenant-id'"
    echo "export AZURE_CLIENT_ID='your-client-id'"
    echo "export AZURE_CLIENT_SECRET='your-client-secret'"
    exit 1
fi

print_success "All required environment variables are set"

# Create temporary playbook with custom user and group
TEMP_PLAYBOOK="/tmp/azure-reset-2fa-temp.yml"

cat > "$TEMP_PLAYBOOK" << EOF
---
- name: Find User in Group and Reset 2FA Authentication using Azure CLI
  hosts: localhost
  gather_facts: false
  
  vars:
    # Azure subscription details
    subscription_id: "{{ lookup('env', 'AZURE_SUBSCRIPTION_ID') }}"
    tenant_id: "{{ lookup('env', 'AZURE_TENANT_ID') }}"
    client_id: "{{ lookup('env', 'AZURE_CLIENT_ID') }}"
    client_secret: "{{ lookup('env', 'AZURE_CLIENT_SECRET') }}"
    
    # Target user and group
    target_user_email: "$USER_EMAIL"
    target_group_name: "$GROUP_NAME"
    
  tasks:
    - name: Check if Azure CLI is installed
      command: az --version
      register: azure_cli_check
      failed_when: false
      changed_when: false
      
    - name: Fail if Azure CLI is not installed
      fail:
        msg: "Azure CLI is required for this playbook. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
      when: azure_cli_check.rc != 0
      
    - name: Login to Azure using service principal
      command: >
        az login --service-principal
        --username {{ client_id }}
        --password {{ client_secret }}
        --tenant {{ tenant_id }}
      register: azure_login
      failed_when: false
      
    - name: Set Azure subscription
      command: az account set --subscription {{ subscription_id }}
      when: azure_login.rc == 0
      
    - name: Get Group Information
      command: az ad group show --group "{{ target_group_name }}" --output json
      register: group_info_json
      when: azure_login.rc == 0
      
    - name: Parse Group Information
      set_fact:
        group_info: "{{ group_info_json.stdout | from_json }}"
      when: group_info_json.rc == 0
      
    - name: Display Group Information
      debug:
        msg: |
          Group Found: {{ group_info.displayName }}
          Group ID: {{ group_info.objectId }}
          Group Description: {{ group_info.description | default('No description') }}
      when: group_info is defined
      
    - name: Fail if group not found
      fail:
        msg: "Group '{{ target_group_name }}' not found in Azure AD"
      when: group_info_json.rc != 0
      
    - name: Get Group Members
      command: az ad group member list --group "{{ target_group_name }}" --output json
      register: group_members_json
      when: group_info is defined
      
    - name: Parse Group Members
      set_fact:
        group_members: "{{ group_members_json.stdout | from_json }}"
      when: group_members_json.rc == 0
      
    - name: Find Target User in Group
      set_fact:
        target_user: "{{ item }}"
      loop: "{{ group_members }}"
      when: 
        - group_members is defined
        - item.mail == target_user_email or item.userPrincipalName == target_user_email
      register: user_found
      
    - name: Display User Search Results
      debug:
        msg: |
          {% if user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0 %}
          ✅ User found in group:
          - Name: {{ user_found.results | selectattr('ansible_facts.target_user', 'defined') | first | json_query('ansible_facts.target_user.displayName') }}
          - Email: {{ user_found.results | selectattr('ansible_facts.target_user', 'defined') | first | json_query('ansible_facts.target_user.mail') }}
          - UPN: {{ user_found.results | selectattr('ansible_facts.target_user', 'defined') | first | json_query('ansible_facts.target_user.userPrincipalName') }}
          - Object ID: {{ user_found.results | selectattr('ansible_facts.target_user', 'defined') | first | json_query('ansible_facts.target_user.objectId') }}
          {% else %}
          ❌ User '{{ target_user_email }}' not found in group '{{ target_group_name }}'
          {% endif %}
          
    - name: Fail if user not found in group
      fail:
        msg: "User '{{ target_user_email }}' not found in group '{{ target_group_name }}'"
      when: user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length == 0
      
    - name: Get User's Current 2FA Status
      command: >
        az ad user show
        --id "{{ target_user_email }}"
        --query "strongAuthenticationRequirements.state"
        --output tsv
      register: user_mfa_status
      when: user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
      
    - name: Get User's MFA Methods
      command: >
        az ad user show
        --id "{{ target_user_email }}"
        --query "strongAuthenticationMethods"
        --output json
      register: user_mfa_methods_json
      when: user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
      
    - name: Parse MFA Methods
      set_fact:
        user_mfa_methods: "{{ user_mfa_methods_json.stdout | from_json }}"
      when: user_mfa_methods_json.rc == 0
      
    - name: Display Current 2FA Status
      debug:
        msg: |
          Current 2FA Status for {{ target_user_email }}:
          - MFA State: {{ user_mfa_status.stdout.strip() if user_mfa_status.stdout else 'Not configured' }}
          - MFA Methods Count: {{ user_mfa_methods | length if user_mfa_methods else 0 }}
          {% if user_mfa_methods %}
          - MFA Methods Details:
          {% for method in user_mfa_methods %}
            - Method Type: {{ method.methodType | default('Unknown') }}
            - Default: {{ method.default | default('N/A') }}
            - Phone Number: {{ method.phoneNumber | default('N/A') }}
          {% endfor %}
          {% endif %}
      when: user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
      
    - name: Confirm 2FA Reset (Dry Run)
      debug:
        msg: |
          ========================================
          DRY RUN - 2FA Reset Operation
          ========================================
          User: {{ target_user_email }}
          Group: {{ target_group_name }}
          Current MFA State: {{ user_mfa_status.stdout.strip() if user_mfa_status.stdout else 'Not configured' }}
          Current MFA Methods: {{ user_mfa_methods | length if user_mfa_methods else 0 }}
          
          This operation will:
          1. Remove all existing MFA methods for the user
          2. Force the user to set up new MFA methods on next login
          3. Send notification to user about MFA reset
          
          To proceed with actual reset, set: force_reset: true
          ========================================
      when: 
        - user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
        - not force_reset | default(false)
        
    - name: Reset User's 2FA Authentication (Remove MFA Methods)
      command: >
        az ad user update
        --id "{{ target_user_email }}"
        --force-change-password-next-login false
      register: user_update_result
      when: 
        - user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
        - force_reset | default(false)
        
    - name: Remove MFA Methods (if any exist)
      command: >
        az ad user update
        --id "{{ target_user_email }}"
        --strong-authentication-methods "[]"
      register: mfa_removal_result
      when: 
        - user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
        - force_reset | default(false)
        - user_mfa_methods and user_mfa_methods | length > 0
        
    - name: Verify 2FA Reset
      command: >
        az ad user show
        --id "{{ target_user_email }}"
        --query "strongAuthenticationRequirements.state"
        --output tsv
      register: user_mfa_status_after
      when: 
        - user_found.results | selectattr('ansible_facts.target_user', 'defined') | list | length > 0
        - force_reset | default(false)
        
    - name: Summary
      debug:
        msg: |
          ========================================
          User 2FA Reset Summary
          ========================================
          Target User: {{ target_user_email }}
          Group: {{ target_group_name }}
          User Found: ✅
          Previous MFA State: {{ user_mfa_status.stdout.strip() if user_mfa_status.stdout else 'Not configured' }}
          Previous MFA Methods: {{ user_mfa_methods | length if user_mfa_methods else 0 }}
          Reset Performed: {{ 'Yes' if force_reset | default(false) else 'No (Dry Run)' }}
          {% if force_reset | default(false) %}
          New MFA State: {{ user_mfa_status_after.stdout.strip() if user_mfa_status_after.stdout else 'Not configured' }}
          {% endif %}
          
          Next Steps:
          {% if force_reset | default(false) %}
          1. ✅ MFA methods have been removed
          2. User will be prompted to set up new MFA on next login
          3. Notify user about the MFA reset
          4. Monitor user's MFA setup completion
          {% else %}
          1. Review the dry run output above
          2. Set force_reset: true to perform actual reset
          3. Run playbook again with: -e "force_reset=true"
          {% endif %}
          ========================================
EOF

# Run the playbook
print_status "Running Ansible playbook..."

if [ "$FORCE_RESET" = true ]; then
    print_warning "Executing actual 2FA reset for user: $USER_EMAIL"
    ansible-playbook "$TEMP_PLAYBOOK" -e "force_reset=true"
else
    print_status "Running dry run to check current status..."
    ansible-playbook "$TEMP_PLAYBOOK"
fi

# Clean up
rm -f "$TEMP_PLAYBOOK"

if [ "$FORCE_RESET" = true ]; then
    print_success "2FA reset completed for user: $USER_EMAIL"
    print_warning "Please notify the user about the MFA reset"
else
    print_success "Dry run completed. To perform actual reset, run:"
    echo "  $0 $USER_EMAIL $GROUP_NAME --force"
fi