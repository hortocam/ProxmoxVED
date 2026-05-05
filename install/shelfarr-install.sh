#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Cameron Horton
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Pedro-Revez-Silva/shelfarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  git \
  curl \
  libsqlite3-dev \
  libvips42 \
  libvips-dev \
  libyaml-dev \
  libssl-dev \
  zlib1g-dev \
  libreadline-dev \
  libffi-dev \
  libxml2-dev \
  libxslt1-dev \
  poppler-utils
msg_ok "Installed Dependencies"

RUBY_VERSION="3.3.6" RUBY_INSTALL_RAILS="false" setup_ruby

msg_info "Cloning Shelfarr"
$STD git clone --depth 1 https://github.com/Pedro-Revez-Silva/shelfarr.git /opt/shelfarr
msg_ok "Cloned Shelfarr"

msg_info "Configuring Shelfarr"
MASTER_KEY=$(openssl rand -hex 16)
SECRET_KEY=$(openssl rand -hex 64)
ENC_PRIMARY=$(openssl rand -base64 32)
ENC_DETERMINISTIC=$(openssl rand -base64 32)
ENC_SALT=$(openssl rand -base64 32)

echo "$MASTER_KEY" >/opt/shelfarr/config/master.key
chmod 600 /opt/shelfarr/config/master.key
rm -f /opt/shelfarr/config/credentials.yml.enc

mkdir -p /opt/shelfarr/storage /opt/shelfarr/log /opt/shelfarr/tmp

cat <<EOF >/opt/shelfarr/.env
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
RAILS_MASTER_KEY=${MASTER_KEY}
SECRET_KEY_BASE=${SECRET_KEY}
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ENC_PRIMARY}
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ENC_DETERMINISTIC}
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ENC_SALT}
SOLID_QUEUE_IN_PUMA=1
PORT=5056
EOF
msg_ok "Configured Shelfarr"

msg_info "Building Application"
cd /opt/shelfarr
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init - bash)" 2>/dev/null || true
export RAILS_ENV=production
set -a
source /opt/shelfarr/.env
set +a
$STD bundle config set --local deployment 'true'
$STD bundle config set --local without 'development:test'
$STD bundle install -j"$(nproc)"
$STD bundle exec rails assets:precompile
$STD bundle exec rails db:prepare
msg_ok "Built Application"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/shelfarr.service
[Unit]
Description=Shelfarr Ebook and Audiobook Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/shelfarr
EnvironmentFile=/opt/shelfarr/.env
Environment=HOME=/root
Environment=PATH=/root/.rbenv/shims:/root/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=BUNDLE_GEMFILE=/opt/shelfarr/Gemfile
Environment=BUNDLE_WITHOUT=development:test
ExecStart=/opt/shelfarr/bin/bundle exec puma -C /opt/shelfarr/config/puma.rb
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now shelfarr
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
