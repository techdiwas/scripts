#!/bin/bash

# Copyright (C) 2025 Diwas Neupane
# SPDX-License-Identifier: Apache-2.0
# Ubuntu Set Up Script (Adapted from Termux version)

# *******************************************************************************
# - Script to generate an SSH key for connection and, a GPG key for security.
# - Upgrades Ubuntu packages and, installs vim, git, openssh, gnupg, etc. packages.
# - Generates an SSH key as well as a GPG key for adding them to GitHub's account.
# - Author: Diwas Neupane (techdiwas)
# - Version: ubuntu:1.0
# - Date: 20251002
# - Adapted for Ubuntu from Termux version
# *******************************************************************************

# validation of username and email
validate_email() {
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$";
    if [[ ! "$1" =~ $email_regex ]]; then
        echo "-- Invalid email address format. Please try again.";
        return 1;
    fi
    return 0;
}

check_inputs() {
  # required credentials
  echo "-- Enter your username:";
  read username;

  while true; do
      echo "-- Enter your email address:";
      read user_email;
      validate_email "$user_email" && break;
  done

  # extra packages
  echo "-- Do you want to install any other packages (Y/n)?";
  read input;
  if [ "$input" = 'y' ] || [ "$input" = 'Y' ]; then
      echo "-- Enter name of the package you want to install:";
      read package_name;
      extra_packages="$package_name gh";
  else
      extra_packages="gh";
  fi
}

# update Ubuntu's environment
update_environment() {
  echo "-- Updating system packages...";
  sudo apt update;
  sudo apt upgrade -y;
}

# install required packages
install_packages() {
  echo "-----------------------------------";
  echo "-- Installing required packages ...";
  echo "-----------------------------------";
  sudo apt install git openssh-client gnupg $extra_packages -y;
  echo "-- Required packages has been installed.";
}

# generate an SSH key
generate_an_ssh_key() {
  echo "---------------------------------------";
  echo "-- Generating an SSH key for GitHub ...";
  echo "---------------------------------------";
  if ssh-keygen -t ed25519 -C "$user_email"; then
      ssh_key="id_ed25519";
  else
      ssh-keygen -t rsa -b 4096 -C "$user_email";
      ssh_key="id_rsa";
  fi
  eval "$(ssh-agent -s)";
  ssh-add ~/.ssh/$ssh_key;
  echo "-- SSH key has been generated and, added to ssh-agent.";
}

# generate a GPG key
generate_a_gpg_key() {
  echo "--------------------------------------";
  echo "-- Generating a GPG key for GitHub ...";
  echo "--------------------------------------";
  gpg --full-generate-key;
  gpg --list-secret-keys --keyid-format=long;
  echo "-- Enter GPG key ID:";
  read gpg_key_id;
  gpg --armor --export $gpg_key_id > ~/.gnupg/id_gpg;
  # configure git for signing key
  git config --global commit.gpgsign true;
  git config --global user.signingkey $gpg_key_id;
  echo "-- GPG key has been generated and, exported.";
}

# configure git for an SSH key and, a GPG key
config_git_for_gpg_key() {
  echo "---------------------------------------";
  echo "-- Configuring git for your GPG key ...";
  echo "---------------------------------------";
  git config --global user.email "$user_email";
  git config --global user.name "$username";

  # set GPG_TTY environment variable to your `.bashrc` startup file
  [ -f ~/.bashrc ] || touch ~/.bashrc;
  # set GPG_TTY environment variable only if it's not already there
  if ! grep -qxF 'export GPG_TTY=$(tty)' ~/.bashrc; then
    echo -e '# Set `GPG_TTY` for GPG (GNU Privacy Guard) passphrase handling.\nexport GPG_TTY=$(tty)' >> ~/.bashrc;
    echo '-- Added GPG_TTY environment variable to `~/.bashrc`.';
  else
    echo '-- GPG_TTY environment variable already present in `~/.bashrc`, skipping...';
  fi
  source ~/.bashrc;
  echo "-- Git configuration completed. Additionally, GPG_TTY has been configured for seamless usage of GPG keys.";
}

# set `nano` as a default editor for git
config_editor() {
  git config --global core.editor "nano"
}

# login to user's GitHub account
config_gh() {
  # check if gh is installed
  if command -v gh >/dev/null 2>&1; then
    echo "-- gh is installed.";
  else
    echo "-- gh is not installed.";
    echo "-- Installing gh...";
    # Install GitHub CLI
    type -p curl >/dev/null || sudo apt install curl -y;
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg;
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg;
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null;
    sudo apt update;
    sudo apt install gh -y;
  fi
  # login to user's GitHub account via gh
  gh auth login;
}

# show an SSH and a GPG public keys for adding them to GitHub account
show_ssh_and_gpg_public_keys() {
  echo "------------------------------------------";
  echo "-- Your SSH public key is displayed below:";
  echo "------------------------------------------";
  cat ~/.ssh/$ssh_key.pub;
  echo "";
  echo "------------------------------------------";
  echo "-- Your GPG public key is displayed below:";
  echo "------------------------------------------";
  cat ~/.gnupg/id_gpg;
  # cleanup junk
  rm ~/.gnupg/id_gpg;
}

# backup GPG key
backup_gpg_key() {
  echo "------------------------";
  echo "-- Backing up GPG key...";
  echo "------------------------";
  gpg --export --export-options backup --output ~/id_gpg_public $user_email;
  gpg --export-secret-keys --export-options backup --output ~/id_gpg_private;
  gpg --export-ownertrust > ~/gpg_ownertrust;
  cat ~/gpg_ownertrust;
  ls -a;
  echo "-- Back up completed.";
}

# backup SSH key
backup_ssh_key() {
  echo "------------------------";
  echo "-- Backing up SSH key...";
  echo "------------------------";
  if [ -f $HOME/.ssh/id_rsa ] && [ -f $HOME/.ssh/id_rsa.pub ]; then
      cp $HOME/.ssh/id_rsa $HOME/.ssh/id_rsa.pub $HOME;
      echo "-- SSH key backed up.";
  elif [ -f $HOME/.ssh/id_ed25519 ] && [ -f $HOME/.ssh/id_ed25519.pub ]; then
      cp $HOME/.ssh/id_ed25519 $HOME/.ssh/id_ed25519.pub $HOME;
      echo "-- SSH key backed up.";
  else
      echo "-- No existing SSH key found.";
  fi
  ls -a;
  echo "-- Back up completed.";
}

# if SSH and GPG keys are stored in GitHub repository then clone it
clone_github_repo() {
    local github_repo_name;
    local github_username;

    echo "-- GitHub Username ?";
    read github_username;
    echo "-- GitHub Reponame ?";
    read github_repo_name;

    sudo apt update;
    # when git is not installed
    if command -v git >/dev/null 2>&1; then
      echo "-- git is installed.";
    else
      echo "-- git is not installed.";
      echo "-- Installing git...";
      sudo apt install git -y;
    fi
    git clone https://github.com/"$github_username"/"$github_repo_name".git;

    if [ -f $github_repo_name/id_gpg_public ] && [ -f $github_repo_name/id_gpg_private ] && [ -f $github_repo_name/gpg_ownertrust ]; then
        cp $github_repo_name/id_gpg_public $github_repo_name/id_gpg_private $github_repo_name/gpg_ownertrust $HOME;
        echo "-- Files copied to $HOME.";
    else
        echo "-- No GPG files found in $github_repo_name.";
    fi
    
    if [ -f $github_repo_name/id_rsa ] && [ -f $github_repo_name/id_rsa.pub ]; then
        cp $github_repo_name/id_rsa $github_repo_name/id_rsa.pub $HOME;
        echo "-- SSH files copied to $HOME.";
    elif [ -f $github_repo_name/id_ed25519 ] && [ -f $github_repo_name/id_ed25519.pub ]; then
        cp $github_repo_name/id_ed25519 $github_repo_name/id_ed25519.pub $HOME;
        echo "-- SSH files copied to $HOME.";
    else
        echo "-- No SSH files found in $github_repo_name.";
    fi

    echo "-- Repository found and SSH and GPG keys are copied.";
    echo "-- Now, you can successfully restore SSH and GPG keys.";

    # cleanup repo
    rm -rf "$github_repo_name";
}

# restore GPG key
restore_gpg_key() {
  echo "--------------------";
  echo "-- Restoring GPG key";
  echo "--------------------";

  sudo apt update;
  # when GNU Privacy Guard (gnupg) is not installed
  if command -v gpg >/dev/null 2>&1; then
    echo "-- GNU Privacy Guard (gnupg) is installed.";
  else
    echo "-- GNU Privacy Guard (gnupg) is not installed.";
    echo "-- Installing GNU Privacy Guard (gnupg)...";
    sudo apt install gnupg -y;
  fi

  # check if files are in $HOME (from clone_github_repo or manual copy)
  if [ -f $HOME/id_gpg_public ] && [ -f $HOME/id_gpg_private ] && [ -f $HOME/gpg_ownertrust ]; then
      echo "-- Files are in $HOME.";
  else
      echo "-- No GPG backup files found in $HOME.";
      echo "-- Please ensure id_gpg_public, id_gpg_private, and gpg_ownertrust are in $HOME.";
      exit 1;
  fi

  gpg --import ~/id_gpg_public;
  gpg --import ~/id_gpg_private;
  gpg --import-ownertrust ~/gpg_ownertrust;

  gpg --list-secret-keys --keyid-format=long;
  echo "-- Enter GPG key ID:";
  read gpg_key_id;

  # Set up trust
  echo "-- Setting up trust level (enter 'trust', then '5', then 'y', then 'quit')";
  gpg --edit-key "$gpg_key_id";
  gpg --list-secret-keys --keyid-format=long;

  # configure git for signing key
  git config --global commit.gpgsign true;
  git config --global user.signingkey $gpg_key_id;
  echo "-- GPG key restored.";

  # cleanup
  rm id_gpg_public id_gpg_private gpg_ownertrust;
}

# restore SSH key
restore_ssh_key() {
  echo "--------------------";
  echo "-- Restoring SSH key";
  echo "--------------------";

  sudo apt update;
  # when OpenSSH client is not installed
  if command -v ssh >/dev/null 2>&1; then
    echo "-- OpenSSH client is installed.";
  else
    echo "-- OpenSSH client is not installed.";
    echo "-- Installing OpenSSH client...";
    sudo apt install openssh-client -y;
  fi

  # Ensure .ssh directory exists
  mkdir -p $HOME/.ssh;
  chmod 700 $HOME/.ssh;

  # check if files are in $HOME (from clone_github_repo or manual copy)
  if [ -f $HOME/id_rsa ] && [ -f $HOME/id_rsa.pub ]; then
      mv $HOME/id_rsa $HOME/id_rsa.pub $HOME/.ssh;
      chmod 600 $HOME/.ssh/id_rsa;
      chmod 644 $HOME/.ssh/id_rsa.pub;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_rsa;
  elif [ -f $HOME/id_ed25519 ] && [ -f $HOME/id_ed25519.pub ]; then
      mv $HOME/id_ed25519 $HOME/id_ed25519.pub $HOME/.ssh;
      chmod 600 $HOME/.ssh/id_ed25519;
      chmod 644 $HOME/.ssh/id_ed25519.pub;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_ed25519;
  else
      echo "-- No SSH key backup found in $HOME.";
      echo "-- Please ensure id_rsa/id_ed25519 and corresponding .pub files are in $HOME.";
      exit 1;
  fi
  echo "-- SSH key restored successfully.";
}

# do all the work!
WorkNow() {
    local SCRIPT_VERSION="ubuntu:1.0-20251002";
    local START=$(date);
    echo "$0, v$SCRIPT_VERSION";
    check_inputs;
    echo "-- What do you want to do today ?";
    echo "-- Setup Ubuntu Environment (s).";
    echo "-- Setup Ubuntu Environment Plus Configure SSH And GPG Keys (ssg).";
    echo "-- Restore from GitHub (rgit).";
    echo "-- Restore SSH Key (rssh).";
    echo "-- Restore GPG Key (rgpg).";
    echo "-- Backup SSH Key (bssh).";
    echo "-- Backup GPG Key (bgpg).";
    read answer;
    case "$answer" in
        "bssh")
            backup_ssh_key;
            ;;
        "bgpg")
            backup_gpg_key;
            ;;
        "rgit")
            clone_github_repo;
            ;;
        "rssh")
            restore_ssh_key;
            ;;
        "rgpg")
            restore_gpg_key;
            config_git_for_gpg_key;
            config_editor;
            config_gh;
            ;;
        "s")
            update_environment;
            install_packages;
            ;;
        "ssg")
            update_environment;
            install_packages;
            config_gh;
            generate_an_ssh_key;
            generate_a_gpg_key;
            config_git_for_gpg_key;
            config_editor;
            show_ssh_and_gpg_public_keys;
            echo "-- Now, you can copy your SSH as well as GPG public keys and, add them to your GitHub's account.";
            ;;
        *)
            local STOP=$(date);
            echo "-- Start time = $START";
            echo "-- Stop time = $STOP";
            exit 0;
            ;;
    esac
}

# --- main() ---
WorkNow;
# --- end main() ---
