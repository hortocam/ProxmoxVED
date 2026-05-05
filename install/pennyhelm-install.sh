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

msg_info "Cloning ${APP}"
$STD git clone --depth 1 https://github.com/administrativetrick/pennyhelm.git /opt/pennyhelm
msg_ok "Cloned ${APP}"

msg_info "Installing Node Modules"
cd /opt/pennyhelm
$STD npm install --omit=dev
mkdir -p /opt/pennyhelm/data
msg_ok "Installed Node Modules"

msg_info "Configuring PennyHelm"
cat <<EOF >/opt/pennyhelm/.env
PLAID_CLIENT_ID=${plaid_client_id}
PLAID_SECRET=${plaid_secret}
PLAID_ENV=${plaid_env}
EOF
msg_ok "Configured PennyHelm"

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
