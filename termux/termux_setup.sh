#!/bin/bash
# *******************************************************************************
# - Script to generate an SSH key for connection and, a GPG key for security.
# - Upgrades Termux packages and, installs vim, git, openssh, gnupg,etc. packages.
# - Generates an SSH key as well as a GPG key for adding them to GitHub's account.
# - Author: Diwas Neupane (techdiwas)
# - Version: generic:1.4
# - Date: 20231225
# - Last modified: 20250606
#
#        - Changes for (20230802)  - make it clear that this script is not ready.
#        - Changes for (20230803)  - make it clear that this script is ready.
#        - Changes for (20231020)  - generate an SSH key and, a GPG key by following official method guided by GitHub.
#        - Changes for (20231020)  - support for creating and, restoring backup.
#        - Changes for (20231224)  - support to restore gnupg files even if termux is fresh.
#        - Changes for (20231225)  - separately back up and restore ssh and gpg keys.
#	 - Changes for (20250606)  - introduce email and username validation. Also, improved overall script.
#	 - Changes for (20250701)  - set up gh for login into user's GitHub account and nano as a default editor for git.
#        - Changes for (20250705)  - auto copy required files from internal storage for restoring purposes.
#
# *******************************************************************************

# check weather we have internal storage access or not
setup_storage() {
    if [ -d "./storage" ]; then
        echo "-- Storage exists. No need to ask for permission.";
    else
        echo "-- Storage is missing in action.";
        echo "-- Setting up internal storage access...";
        termux-setup-storage;
    fi
}

# change termux package repository
setup_repo() {
    termux-change-repo;
}

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

# update Termux's environment
update_environment() {
  pkg update && pkg upgrade -y;
}

# install required packages
install_packages() {
  echo "-----------------------------------";
  echo "-- Installing required packages ...";
  echo "-----------------------------------";
  pkg install git openssh gnupg $extra_packages -y;
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
  # add GPG key to your `.bashrc` startup file
  [ -f ~/.bashrc ] || touch ~/.bashrc && echo -e '# Set `GPG_TTY` for GPG (GNU Privacy Guard) passphrase handling\nexport GPG_TTY=$(tty)' >> ~/.bashrc;
  source ~/.bashrc;
  echo "-- Git configuration completed. Additionally, GPG_TTY has been configured for seamless usage of GPG keys.";
}

# set `nano` as a default editor for git
config_editor() {
  git config --global core.editor "nano"
}

# login to user's GitHub account
config_gh() {
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

# restore GPG key
restore_gpg_key() {
  echo "--------------------";
  echo "-- Restoring GPG key";
  echo "--------------------";
  pkg update;
  # when GNU Privacy Guard (gnupg) is not installed
  if dpkg -s gnupg >/dev/null 2>&1; then
    echo "-- GNU Privacy Guard (gnupg) is installed.";
  else
    echo "-- GNU Privacy Guard (gnupg) is not installed.";
    echo "-- Installing GNU Privacy Guard (gnupg)...";
    pkg install gnupg;
  fi

  # assume files are in this dir. So copy them.
  int_storage=storage/shared/Download;
  if [ -f $int_storage/id_gpg_public ] && [ -f $int_storage/id_gpg_private ] && [ -f $int_storage/gpg_ownertrust ]; then
      cp $int_storage/id_gpg_public $int_storage/id_gpg_private $int_storage/gpg_ownertrust $HOME;
      echo "-- Files copied.";
  else
      echo "-- No files found in $int_storage.";
  fi

  if [ -f $HOME/id_gpg_public ] && [ -f $HOME/id_gpg_private ] && [ -f $HOME/gpg_ownertrust ]; then
      gpg --import ~/id_gpg_public;
      gpg --import ~/id_gpg_private;
      gpg --import ~/gpg_ownertrust;
  else
     echo "-- No files exists in $HOME to restore.";
     exit 1;
  fi

  gpg --list-secret-keys --keyid-format=long;
  echo "-- Enter GPG key ID:";
  read gpg_key_id;

  # configure git for signing key
  git config --global commit.gpgsign true;
  git config --global user.signingkey $gpg_key_id;
  echo "-- Restored.";

  # cleanup
  rm id_gpg_public id_gpg_private gpg_ownertrust;
}

# restore SSH key
restore_ssh_key() {
  echo "--------------------";
  echo "-- Restoring SSH key";
  echo "--------------------";

  # when OpenSSH (Open Secure Shell) is not installed
  if dpkg -s openssh >/dev/null 2>&1; then
    echo "-- OpenSSH (Open Secure Shell) is installed.";
  else
    echo "-- OpenSSH (Open Secure Shell) is not installed.";
    echo "-- Installing OpenSSH (Open Secure Shell)...";
    pkg install openssh;
  fi

  # assume files are in this dir. So copy them.
  int_storage=storage/shared/Download;
  if [ -f $int_storage/id_rsa ] && [ -f $int_storage/id_rsa.pub ]; then
      cp $int_storage/id_rsa $int_storage/id_rsa.pub $HOME;
      echo "-- Files copied.";
  elif [ -f $int_storage/id_ed25519 ] && [ -f $int_storage/id_ed25519.pub ]; then
      cp $int_storage/id_ed25519 $int_storage/id_ed25519.pub $HOME;
      echo "-- Files copied.";
  else
      echo "-- No files found in $int_storage.";
      exit 1;
  fi

  if [ -f $HOME/id_rsa ] && [ -f $HOME/id_rsa.pub ]; then
      mv $HOME/id_rsa $HOME/id_rsa.pub $HOME/.ssh;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_rsa;
  elif [ -f $HOME/id_ed25519 ] && [ -f $HOME/id_ed25519.pub ]; then
      mv $HOME/id_ed25519 $HOME/id_ed25519.pub $HOME/.ssh;
      echo "-- SSH key restored.";
      eval "$(ssh-agent -s)";
      ssh-add ~/.ssh/id_ed25519;
  else
      echo "-- No SSH key backup found.";
  fi
  echo "-- Restored.";
}

# do all the work!
WorkNow() {
    local SCRIPT_VERSION="20250701";
    local START=$(date);
    local STOP=$(date);
    echo "$0, v$SCRIPT_VERSION";
    check_inputs;
    echo "-- What do you want to do today ?";
    echo "-- Setup Termux's Environment (s).";
    echo "-- Setup Termux's Environment Plus Configure SSH And GPG Keys (ssg).";
    echo "-- Restore SSH Key (rs).";
    echo "-- Restore GPG Key (rg).";
    echo "-- Backup SSH Key (bs).";
    echo "-- Backup GPG Key (bg).";
    read answer;
    case "$answer" in
        "bs")
            backup_ssh_key;
            ;;
        "bg")
            backup_gpg_key;
            ;;
        "rs")
            restore_ssh_key;
            ;;
        "rg")
            restore_gpg_key;
            config_git_for_gpg_key;
	    config_editor;
	    config_gh;
            ;;
        "s")
            setup_storage;
            setup_repo;
            update_environment;
            install_packages;
            ;;
      "ssg")
            setup_storage;
            setup_repo;
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
            echo "-- Start time = $START";
            echo "-- Stop time = $STOP";
            exit 0;
            ;;
    esac
}

# --- main() ---
WorkNow;
# --- end main() ---
