# Projet Final - Industrialisation Zero Touch

Deploiement automatise d'une stack applicative (Frontend, Backend, DB, Adminer) sur AWS via une pipeline CI/CD, sans aucune intervention SSH manuelle.

## Architecture

```
                    +----------------------+
                    |   GitHub Actions     |
                    |   (workflow_dispatch)|
                    +------+---------------+
                           |
            +--------------+--------------+
            v              v              v
     Build & Push     Terraform       Ansible
     (images)        (infra EC2)    (config + deploy)
            |              |              |
            v              v              v
   +-------------+  +-----------+  +---------------+
   | EC2 Registry|  | EC2 App   |  | EC2 App       |
   | (HTTPS/SSL) |  | (creee)   |  | (configuree)  |
   | :443        |  |           |  |               |
   +-------------+  +-----------+  +---------------+
```

### EC2 Registry (pre-existante)
- Registry Docker prive (registry:2)
- Reverse Proxy Nginx + SSL auto-signe
- Authentification htpasswd
- Port 443 (HTTPS)

### EC2 Application (ephemere, creee par la pipeline)
- Frontend : port 80
- Backend API : port 3000
- PostgreSQL : interne uniquement
- Adminer : port 8081

## Prerequis

### GitHub Secrets a configurer

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Cle d'acces AWS |
| `AWS_SECRET_ACCESS_KEY` | Cle secrete AWS |
| `REGISTRY_IP` | IP publique de l'EC2 Registry |
| `REGISTRY_USER` | Utilisateur du registre |
| `REGISTRY_PASSWORD` | Mot de passe du registre |
| `DB_NAME` | Nom de la base de donnees |
| `DB_USER` | Utilisateur de la base de donnees |
| `DB_PASSWORD` | Mot de passe de la base de donnees |

## Lancer le deploiement

1. Configurer les GitHub Secrets ci-dessus
2. Aller dans **Actions** > **Deploy Application** > **Run workflow**
3. Attendre la fin du pipeline
4. Les URLs sont affichees dans le resume du job

## Structure du projet

```
.github/workflows/blank.yml    # Pipeline CI/CD (workflow_dispatch)
infra/app/main.tf              # Terraform (EC2 applicative)
infra/registry/main.tf         # Terraform (EC2 registre Docker)
ansible/playbook.yml           # Ansible (configuration serveur)
ansible/templates/             # Templates (docker-compose, nginx)
registry/                      # Terraform + Ansible du registre Docker
frontend/                      # Code source + Dockerfile frontend
backend/                       # Code source + Dockerfile backend
.env.sample                    # Liste des secrets a configurer
```

## Destruction

L'infrastructure applicative est ephemere (tfstate local au runner). Pour la detruire manuellement :

```bash
cd infra/app
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
terraform init
terraform destroy -auto-approve
```
