#!/bin/bash
# This script installs zsh, oh my zsh and configures powerlvl10k as the default theme for zsh
# changes the default path on WSL distributions to /home/$USER
# and installs these tools:
#  - docker

wsl_home () {
  if ! grep -q WSL /proc/version; then
    return
  fi

  if grep -q WSL ~/.zshrc; then
    return
  fi

  printf "# WSL Config\ncd\n" >> ~/.zshrc
}

# update repository and install dependencies
sudo apt-get update && sudo apt-get install curl git -y

# install and set by default zsh
# install ohmyzsh
sudo apt-get install zsh -y
sudo chsh -s $(which zsh) `whoami`
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# customize .zshrc
# download powerlvl10k and modify zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
curl https://raw.githubusercontent.com/dloez/dloez/main/shell/zshrc > $HOME/.zshrc
curl https://raw.githubusercontent.com/dloez/dloez/main/shell/p10k.zsh > $HOME/.p10k.zsh

# customize .zshrc if we are on WSL to use /home/$USER as default location
wsl_home

# install tools
# docker
sudo apt-get install -y ca-certificates gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker `whoami`
