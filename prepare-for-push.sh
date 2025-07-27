#!/bin/bash
# Prepare Kollaa Fleet for pushing to GitHub/Gerrit

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}Preparing Kollaa Fleet for Push${NC}"
echo ""

# Add Apache license headers to shell scripts
add_license_header() {
    local file=$1
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    # Check if license header already exists
    if grep -q "Apache License" "$file"; then
        return
    fi
    
    echo -e "${CYAN}Adding license header to $file${NC}"
    
    # Create temp file with license header
    cat > /tmp/license_header.txt << 'EOF'
#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

EOF
    
    # Skip the shebang line and prepend license
    tail -n +2 "$file" > /tmp/file_content.txt
    cat /tmp/license_header.txt /tmp/file_content.txt > "$file"
    rm -f /tmp/license_header.txt /tmp/file_content.txt
}

# Check for required files
echo -e "${BLUE}Checking required files...${NC}"
required_files=(
    "deploy-openstack.sh"
    "install.sh"
    "install-deploy.sh"
    "rollback.sh"
    "README.md"
    "requirements.txt"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    else
        echo -e "${GREEN}✓ $file${NC}"
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required files: ${missing_files[*]}${NC}"
    exit 1
fi

# Add license headers
echo ""
echo -e "${BLUE}Adding license headers...${NC}"
for script in *.sh scripts/*.sh; do
    add_license_header "$script"
done

# Create .gitignore if not exists
if [[ ! -f .gitignore ]]; then
    echo -e "${BLUE}Creating .gitignore...${NC}"
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*.pyc
.Python
venv/
.venv

# Ansible
*.retry

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Deployment files
deployment-config/
passwords.yml
*.backup
*.log

# Temporary
*.tmp
*.temp
EOF
fi

# Check file permissions
echo ""
echo -e "${BLUE}Checking file permissions...${NC}"
for script in *.sh scripts/*.sh; do
    if [[ -f "$script" ]]; then
        if [[ ! -x "$script" ]]; then
            echo -e "${YELLOW}Making $script executable${NC}"
            chmod +x "$script"
        fi
    fi
done

# Initialize git if needed
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}Initializing git repository...${NC}"
    git init
    git add .
    git commit -m "Initial commit: Kollaa Fleet deployment automation

- Interactive installer for Kolla-Ansible
- Multi-node deployment support
- Comprehensive rollback system
- Support for RHEL and Debian-based systems"
fi

# Create initial git tag
echo ""
echo -e "${BLUE}Creating version tag...${NC}"
git tag -a v1.0.0 -m "Initial release of Kollaa Fleet" 2>/dev/null || echo "Tag already exists"

# Summary
echo ""
echo -e "${GREEN}${BOLD}Repository prepared successfully!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "1. Create a GitHub repository for your fork"
echo "2. Run ./push-and-merge.sh to set up remotes"
echo "3. Push to your fork"
echo "4. Create a pull request"
echo ""
echo -e "${YELLOW}Alternative: Direct contribution${NC}"
echo "1. Clone openstack/kolla-ansible"
echo "2. Copy files to tools/kollaa-fleet/"
echo "3. Submit via Gerrit"
echo ""
echo -e "${GREEN}Good luck with your contribution!${NC}"