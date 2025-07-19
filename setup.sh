#!/bin/bash

# Azure Users Ansible Playbook Setup Script

echo "=========================================="
echo "Azure Users Ansible Playbook Setup"
echo "=========================================="

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed. Please install Ansible first."
    echo "   Visit: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
    exit 1
fi

echo "✅ Ansible is installed: $(ansible --version | head -n1)"

# Check if pip is available
if ! command -v pip &> /dev/null; then
    echo "❌ pip is not installed. Please install pip first."
    exit 1
fi

echo "✅ pip is available"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install azure-identity azure-mgmt-graphrbac msrest

if [ $? -eq 0 ]; then
    echo "✅ Python dependencies installed successfully"
else
    echo "❌ Failed to install Python dependencies"
    exit 1
fi

# Install Ansible collections
echo "📦 Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml

if [ $? -eq 0 ]; then
    echo "✅ Ansible collections installed successfully"
else
    echo "❌ Failed to install Ansible collections"
    exit 1
fi

# Check if Azure CLI is installed (optional)
if command -v az &> /dev/null; then
    echo "✅ Azure CLI is installed: $(az version --output table | head -n2 | tail -n1)"
    echo ""
    echo "💡 You can use Azure CLI to create a service principal:"
    echo "   az login"
    echo "   az ad sp create-for-rbac --name 'ansible-azure-users' --role 'Directory.Read.All'"
else
    echo "⚠️  Azure CLI is not installed (optional but recommended)"
    echo "   Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

echo ""
echo "=========================================="
echo "Setup Complete! 🎉"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Set up your Azure service principal"
echo "2. Configure environment variables:"
echo "   export AZURE_SUBSCRIPTION_ID='your-subscription-id'"
echo "   export AZURE_TENANT_ID='your-tenant-id'"
echo "   export AZURE_CLIENT_ID='your-client-id'"
echo "   export AZURE_CLIENT_SECRET='your-client-secret'"
echo ""
echo "3. Run the playbook:"
echo "   ansible-playbook azure-users-playbook.yml"
echo ""
echo "For detailed instructions, see README.md"