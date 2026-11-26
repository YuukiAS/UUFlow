#!/bin/zsh
# UUFlow.app 的可回滚安装事务。调用方必须先让正在运行的新旧 App 完成正常退出。

uuflow_verify_candidate() {
  local app=$1 executable name bundle
  [[ -d "$app" ]] || return 1
  name="$(plutil -extract CFBundleDisplayName raw -o - "$app/Contents/Info.plist" 2>/dev/null)" || return 1
  bundle="$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist" 2>/dev/null)" || return 1
  executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist" 2>/dev/null)" || return 1
  [[ $name == UUFlow && $bundle == com.zephyr4123.snug && -x "$app/Contents/MacOS/$executable" ]]
}

uuflow_prepare_install() {
  local source=$1 apps_dir=$2
  [[ -n $source && -n $apps_dir && $apps_dir != / ]] || return 2
  [[ ${source:t} == UUFlow.app ]] || return 2
  UUFLOW_INSTALL_TARGET="$apps_dir/UUFlow.app"
  UUFLOW_INSTALL_LEGACY="$apps_dir/Snug.app"
  UUFLOW_INSTALL_STAGE="$apps_dir/.UUFlow.app.stage.$$"
  UUFLOW_INSTALL_BACKUP="$apps_dir/.UUFlow.app.backup.$$"
  [[ ! -e $UUFLOW_INSTALL_STAGE && ! -e $UUFLOW_INSTALL_BACKUP ]] || return 2

  ditto "$source" "$UUFLOW_INSTALL_STAGE" || return 1
  if ! uuflow_verify_candidate "$UUFLOW_INSTALL_STAGE"; then
    rm -rf "$UUFLOW_INSTALL_STAGE"
    return 1
  fi
  if [[ -e $UUFLOW_INSTALL_TARGET ]]; then
    mv "$UUFLOW_INSTALL_TARGET" "$UUFLOW_INSTALL_BACKUP" || { rm -rf "$UUFLOW_INSTALL_STAGE"; return 1; }
  fi
  if ! mv "$UUFLOW_INSTALL_STAGE" "$UUFLOW_INSTALL_TARGET"; then
    [[ -e $UUFLOW_INSTALL_BACKUP ]] && mv "$UUFLOW_INSTALL_BACKUP" "$UUFLOW_INSTALL_TARGET"
    return 1
  fi
}

uuflow_commit_install() {
  [[ -n ${UUFLOW_INSTALL_TARGET:-} && -d $UUFLOW_INSTALL_TARGET ]] || return 1
  uuflow_verify_candidate "$UUFLOW_INSTALL_TARGET" || return 1
  [[ -n ${UUFLOW_INSTALL_BACKUP:-} ]] && rm -rf "$UUFLOW_INSTALL_BACKUP"
  [[ -n ${UUFLOW_INSTALL_LEGACY:-} ]] && rm -rf "$UUFLOW_INSTALL_LEGACY"
}

uuflow_rollback_install() {
  [[ -n ${UUFLOW_INSTALL_TARGET:-} ]] || return 2
  rm -rf "$UUFLOW_INSTALL_TARGET" "${UUFLOW_INSTALL_STAGE:-/dev/null}"
  if [[ -n ${UUFLOW_INSTALL_BACKUP:-} && -e $UUFLOW_INSTALL_BACKUP ]]; then
    mv "$UUFLOW_INSTALL_BACKUP" "$UUFLOW_INSTALL_TARGET"
  fi
}
