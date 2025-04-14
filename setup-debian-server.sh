#!/bin/bash
# Script de configuration d'un serveur Debian minimaliste pour le déploiement de Harmoneyz
# À exécuter en tant que root

set -e  # Exit immédiatement si une commande échoue

# Fonction pour afficher les étapes
print_step() {
  echo "============================================"
  echo ">>> $1"
  echo "============================================"
}

# Vérifier qu'on est bien root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root" >&2
  exit 1
fi

# 1. Mise à jour du système
print_step "Mise à jour du système"
apt-get update
apt-get upgrade -y

# 2. Installation des packages de base
print_step "Installation des paquets de base"
apt-get install -y sudo curl wget gnupg2 ca-certificates lsb-release apt-transport-https

# 3. Création de l'utilisateur deploy
print_step "Création de l'utilisateur deploy"
if ! id "deploy" &>/dev/null; then
  useradd -m -s /bin/bash deploy || {
    # Si useradd n'est pas disponible, créer l'utilisateur manuellement
    mkdir -p /home/deploy
    echo "deploy:x:1001:1001::/home/deploy:/bin/bash" >> /etc/passwd
    echo "deploy:x:1001:" >> /etc/group
    chown -R deploy:deploy /home/deploy
  }
  
  # Définir un mot de passe aléatoire (commentez si vous préférez définir un mot de passe manuellement)
  TEMP_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
  echo "deploy:$TEMP_PASSWORD" | chpasswd
  echo "Mot de passe temporaire pour deploy: $TEMP_PASSWORD"
  
  # Ajouter l'utilisateur au groupe sudo
  apt-get install -y sudo
  usermod -aG sudo deploy
  echo "deploy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/deploy
  chmod 440 /etc/sudoers.d/deploy
fi

# 4. Configuration SSH
print_step "Configuration SSH"
mkdir -p /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys

echo "Veuillez coller votre clé SSH publique pour l'utilisateur deploy (laissez vide pour sauter):"
read -r SSH_KEY
if [ -n "$SSH_KEY" ]; then
  echo "$SSH_KEY" > /home/deploy/.ssh/authorized_keys
  echo "Clé SSH ajoutée pour l'utilisateur deploy"
else
  echo "Aucune clé SSH ajoutée. Vous devrez le faire manuellement plus tard."
fi

chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# 5. Installation de Docker
print_step "Installation de Docker"
# Désinstaller les anciennes versions
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Configuration du dépôt Docker
mkdir -p /etc/apt/keyrings
if command -v gpg >/dev/null 2>&1; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
else
  curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
fi

# Ajouter le dépôt
if [ -f /etc/apt/keyrings/docker.gpg ]; then
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
fi

# Mettre à jour et installer Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Vérifier que Docker fonctionne
docker --version
docker run hello-world || echo "Erreur lors de l'exécution de hello-world, mais on continue..."

# Ajouter l'utilisateur deploy au groupe docker
usermod -aG docker deploy

# 6. Installation de Docker Compose
print_step "Installation de Docker Compose"
# Installer Docker Compose v1 (standalone)
DOCKER_COMPOSE_VERSION="2.20.3"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version || echo "Docker Compose n'a pas pu être installé correctement"

# 7. Configuration du pare-feu
print_step "Configuration du pare-feu"
if command -v ufw >/dev/null 2>&1; then
  # UFW est disponible
  apt-get install -y ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow http
  ufw allow https
  ufw --force enable
else
  # Utiliser iptables directement
  apt-get install -y iptables-persistent
  
  # Règles de base
  iptables -F
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  iptables -A INPUT -j DROP
  
  # Sauvegarder les règles
  netfilter-persistent save
fi

print_step "Configuration terminée avec succès !"
echo ""
echo "Récapitulatif:"
echo "- Utilisateur deploy créé"
if [ -n "$TEMP_PASSWORD" ]; then
  echo "- Mot de passe temporaire: $TEMP_PASSWORD"
fi
echo "- Docker et Docker Compose installés"
echo "- Pare-feu configuré (ports 22, 80, 443 ouverts)"
echo ""
echo "Pour vous connecter en tant qu'utilisateur deploy:"
echo "ssh deploy@VOTRE_ADRESSE_IP"
echo ""
echo "Pour vérifier que Docker fonctionne correctement:"
echo "docker run hello-world"
echo "" 