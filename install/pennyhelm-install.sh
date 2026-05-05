#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Cameron Horton
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/administrativetrick/pennyhelm

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y git
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs

msg_info "Cloning PennyHelm"
$STD git clone --depth 1 https://github.com/administrativetrick/pennyhelm.git /opt/pennyhelm
msg_ok "Cloned PennyHelm"

msg_info "Installing Node Modules"
cd /opt/pennyhelm
$STD npm install --omit=dev
mkdir -p /opt/pennyhelm/data
msg_ok "Installed Node Modules"

read -r -p "${TAB3}Would you like to configure Plaid integration? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Configuring Plaid"
  if [[ -z "${var_plaid_client_id:-}" ]]; then
    read -r -p "${TAB3}Plaid Client ID: " var_plaid_client_id
  fi
  if [[ -z "${var_plaid_secret:-}" ]]; then
    read -r -p "${TAB3}Plaid Secret: " var_plaid_secret
  fi
  if [[ -z "${var_plaid_env:-}" ]]; then
    echo -e "${TAB3}Plaid Environment:"
    echo -e "${TAB3}  1) sandbox"
    echo -e "${TAB3}  2) development"
    echo -e "${TAB3}  3) production"
    read -r -p "${TAB3}Select environment [1-3] (default: 1): " plaid_env_choice
    case "${plaid_env_choice}" in
      2) var_plaid_env="development" ;;
      3) var_plaid_env="production" ;;
      *) var_plaid_env="sandbox" ;;
    esac
  fi
  cat <<EOF >/opt/pennyhelm/.env
PLAID_CLIENT_ID=${var_plaid_client_id}
PLAID_SECRET=${var_plaid_secret}
PLAID_ENV=${var_plaid_env}
EOF
  msg_ok "Configured Plaid"
fi

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/pennyhelm.service
[Unit]
Description=PennyHelm Personal Finance Tracker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/pennyhelm
Environment=PORT=8081
EnvironmentFile=-/opt/pennyhelm/.env
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now pennyhelm
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
