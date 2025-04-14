# Guide de déploiement Harmoneyz sur VPS OVH (Debian)

Ce guide vous explique comment configurer votre VPS OVH sous Debian et mettre en place un déploiement automatique avec GitHub Actions pour votre application Harmoneyz, **sans utiliser Docker Hub**.

## Table des matières

1. [Prérequis](#prérequis)
2. [Configuration du VPS OVH](#configuration-du-vps-ovh)
3. [Configuration de Docker](#configuration-de-docker)
4. [Configuration de GitHub Actions](#configuration-de-github-actions)
5. [Premier déploiement](#premier-déploiement)
6. [Dépannage](#dépannage)

## Prérequis

- Un compte OVH avec un VPS sous Debian (recommandé : au moins 2 Go de RAM)
- Un nom de domaine (facultatif, mais recommandé)
- Un compte GitHub

## Configuration du VPS OVH

### 1. Accéder à votre VPS

Connectez-vous à votre VPS via SSH :

```bash
ssh root@votre_ip_vps
```

Lors de la première connexion, OVH vous demandera de changer le mot de passe root.

### 2. Utilisateur par défaut (debian)

Les VPS OVH sous Debian sont généralement livrés avec un utilisateur "debian" préconfiguré. Nous utiliserons cet utilisateur pour le déploiement plutôt que d'en créer un nouveau.

```bash
# Vérifier que l'utilisateur debian existe
id debian

# Ajouter l'utilisateur debian au groupe sudo s'il n'y est pas déjà
usermod -aG sudo debian

# Configurer SSH pour cet utilisateur
mkdir -p /home/debian/.ssh
touch /home/debian/.ssh/authorized_keys

# Copiez votre clé publique SSH dans le fichier authorized_keys
cat > /home/debian/.ssh/authorized_keys << EOF
votre-clé-ssh-publique-ici
EOF
# OU utilisez nano/vi pour éditer le fichier
# nano /home/debian/.ssh/authorized_keys

# Définir les bonnes permissions
chmod 700 /home/debian/.ssh
chmod 600 /home/debian/.ssh/authorized_keys
chown -R debian:debian /home/debian/.ssh
```

### 3. Configurer le pare-feu

Si UFW n'est pas disponible, vous pouvez utiliser iptables directement :

```bash
# Installer UFW (Uncomplicated Firewall) si disponible
apt-get update
apt-get install -y ufw

# Configuration avec UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# OU utiliser iptables directement si UFW n'est pas disponible
# Autoriser SSH (port 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# Autoriser HTTP (port 80)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# Autoriser HTTPS (port 443)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
# Autoriser les connexions établies et apparentées
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# Autoriser le loopback
iptables -A INPUT -i lo -j ACCEPT
# Bloquer le reste du trafic entrant
iptables -A INPUT -j DROP

# Rendre les règles iptables persistantes
apt-get install -y iptables-persistent
netfilter-persistent save
```

### 4. Mettre à jour le système

```bash
apt-get update && apt-get upgrade -y
```

## Configuration de Docker

### 1. Installer Docker et Docker Compose sur Debian minimaliste

Pour les installations minimales de Debian, vous devrez peut-être installer des outils supplémentaires :

```bash
# Installer les outils de base et dépendances
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Désinstaller les anciennes versions si nécessaire
apt-get remove -y docker docker-engine docker.io containerd runc

# Ajouter la clé GPG officielle de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Si la commande gpg n'est pas disponible, utilisez cette alternative
# curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

# Configurer le dépôt Docker - méthode moderne
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# OU méthode alternative si la méthode moderne ne fonctionne pas
# echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Mettre à jour la liste des paquets
apt-get update

# Installer Docker Engine
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Vérifier que Docker fonctionne
docker run hello-world

# Installer Docker Compose v2 via le plugin de Docker
# Pour utiliser docker compose, vous utiliserez 'docker compose' au lieu de 'docker-compose'

# Si vous préférez l'ancienne commande docker-compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 2. Ajouter l'utilisateur debian au groupe docker

Pour que l'utilisateur debian puisse utiliser Docker sans sudo :

```bash
usermod -aG docker debian
# Assurez-vous de vous déconnecter et reconnecter pour que les changements prennent effet
```

Si vous ne pouvez pas ajouter l'utilisateur au groupe docker, le workflow est configuré pour utiliser sudo automatiquement.

## Configuration de GitHub Actions

### 1. Générer une paire de clés SSH pour GitHub Actions

Sur votre machine locale :

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_actions_deploy -C "github-actions-deploy"
```

### 2. Ajouter la clé publique au VPS

Copiez le contenu de `~/.ssh/github_actions_deploy.pub` dans le fichier `/home/debian/.ssh/authorized_keys` sur votre VPS.

### 3. Configurer les secrets dans GitHub

Dans votre dépôt GitHub, allez dans Settings > Secrets > Actions et ajoutez les secrets suivants :

- `SSH_PRIVATE_KEY` : contenu de votre clé privée `~/.ssh/github_actions_deploy`
- `VPS_HOST` : adresse IP ou nom d'hôte de votre VPS

> **Note:** L'utilisateur "debian" est configuré directement dans le workflow et n'a pas besoin d'être défini comme secret.

## Premier déploiement

### 1. Configurer un nom de domaine (facultatif)

Dans votre interface OVH :
1. Allez dans votre zone DNS
2. Créez un enregistrement A pointant vers l'adresse IP de votre VPS
3. Attendez la propagation DNS (peut prendre jusqu'à 24h)

### 2. Déclencher le déploiement

Poussez vos modifications vers la branche main de votre dépôt GitHub ou déclenchez manuellement le workflow dans l'onglet Actions.

Voici comment fonctionne le workflow de déploiement sans Docker Hub :

1. GitHub Actions compresse votre code dans une archive
2. L'archive est transférée vers votre VPS via SCP
3. Sur le VPS, l'archive est extraite
4. L'image Docker est construite localement sur le VPS
5. L'application est déployée avec Docker Compose

### 3. Vérifier le déploiement

Accédez à votre site via votre nom de domaine ou l'adresse IP de votre VPS.

## Dépannage

### Logs Docker et commandes utiles

```bash
# Voir les conteneurs en cours d'exécution
docker ps
# OU si vous n'avez pas les permissions
sudo docker ps

# Vérifier les logs de l'application
docker logs -f harmoneyz-harmoneyz-1
# OU
sudo docker logs -f harmoneyz-harmoneyz-1

# Redémarrer l'application
cd ~/harmoneyz
docker-compose restart
# OU
sudo docker-compose restart
# OU avec Docker Compose V2
docker compose restart
# OU
sudo docker compose restart

# Reconstruire l'image et redémarrer les services après une mise à jour manuelle
cd ~/harmoneyz
docker build -t harmoneyz:latest .
docker-compose up -d --force-recreate
# OU si vous n'avez pas les permissions
sudo docker build -t harmoneyz:latest .
sudo docker-compose up -d --force-recreate
```

### Problèmes courants

1. **Le site n'est pas accessible**
   - Vérifiez que le conteneur est en cours d'exécution : `docker ps` ou `sudo docker ps`
   - Vérifiez les logs du conteneur : `cd ~/harmoneyz && docker-compose logs` ou `sudo docker-compose logs`
   - Assurez-vous que le port 80 est ouvert dans le pare-feu
   - Vérifiez que Docker est bien en cours d'exécution : `systemctl status docker`

2. **Erreurs lors du déploiement GitHub Actions**
   - Vérifiez les logs GitHub Actions dans l'onglet Actions de votre dépôt
   - Assurez-vous que le secret SSH_PRIVATE_KEY est correctement configuré
   - Vérifiez la connectivité SSH vers votre VPS
   - Assurez-vous que l'utilisateur `debian` a les permissions d'exécuter Docker ou sudo

3. **Erreurs lors de la construction de l'image sur le VPS**
   - Vérifiez les ressources du VPS (mémoire, CPU, espace disque)
   - Consultez les logs Docker : `docker logs -f harmoneyz-harmoneyz-1` ou `sudo docker logs -f harmoneyz-harmoneyz-1`
   - Essayez de construire l'image manuellement : `cd ~/harmoneyz && docker build -t harmoneyz:latest .` ou `sudo docker build -t harmoneyz:latest .`
   - Vérifiez si l'utilisateur a les permissions Docker : `groups` (devrait inclure 'docker')

4. **Erreurs Docker**
   - Vérifiez l'espace disque disponible : `df -h`
   - Nettoyez les images non utilisées : `docker system prune -a` ou `sudo docker system prune -a`
   - Redémarrez Docker si nécessaire : `sudo systemctl restart docker` 