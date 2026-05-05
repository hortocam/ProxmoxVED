#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Cameron Horton
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Pedro-Revez-Silva/shelfarr

APP="Shelfarr"
var_tags="${var_tags:-books;ebooks;audiobooks;arr}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/shelfarr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping Service"
  systemctl stop shelfarr
  msg_ok "Stopped Service"

  msg_info "Updating ${APP}"
  cd /opt/shelfarr
  $STD git pull
  export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
  eval "$(rbenv init - bash)" 2>/dev/null || true
  set -a && source /opt/shelfarr/.env && set +a
  $STD bundle install -j"$(nproc)"
  $STD bundle exec rails assets:precompile
  $STD bundle exec rails db:migrate
  msg_ok "Updated ${APP}"

  msg_info "Starting Service"
  systemctl start shelfarr
  msg_ok "Started Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5056${CL}"
