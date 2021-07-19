# SECRET : Secure Environment for automatic test grading

> Travail de Bachelor 2020-2021
>
> Auteur : Caroline Monthoux
>
> Modifié par : Stéphane Teixeira Carvalho
>
> Date : 29.07.2021



## Introduction

Ce document est une marche à suivre pour configurer l'environnement tel que mis en place dans le projet.

L'arborescence de dossiers est la suivante :

* `Installation/` contient tous les scripts d'installation de l'environnement et des annexes qui sont cités dans ce document.
* `Python_Scripts/` contient des scripts python permettant l'automatisation de certaines actions. Leur utilisations seront spécifiées dans les étapes où ceux-ci peuvent être utilisé.
* `Templates/` contient des fichiers servant de modèle pour les applications Zabbix et Grafana.

**Ce document ainsi que les scripts qui l'accompagnent sont disponibles dans un dépôt GitHub. Vous pouvez y accéder à l'adresse https://github.com/Naludrag/SECRET-II-Installation. **

## Procédure d'installation de l'environnement

Avant de commencer, il est nécessaire de disposer d'au moins 2 ordinateurs, l'un faisant office de serveur et l'autre de client. Il est assumé que :

* Le serveur est fraîchement installé avec Ubuntu 20.04 Desktop (installation normale, pas minimale)
* Les paramètres liés au pays et à la langue sont corrects (localisation `Europe/Zurich`, clavier `Switzerland - French`)
* La topologie réseau est prête (le serveur est branché au réseau local par une interface et au(x) client(s) par une autre interface)

Avant de continuer, il faut être en possession de :

* Un compte utilisateur capable d'administrer le serveur (faisant partie du groupe sudo)
* Le nom de l'interface connectée au réseau local (réseau de l'école ou de la maison)
* Le nom de l'interface connectée au réseau LTSP

Les scripts sont conçus pour être lancés par un utilisateur sudoer depuis son /home, mais **pas directement par root**.

#### Étape 1 : premiers paramétrages du serveur

Éditer le fichier script `01.setup_server` pour remplacer les noms des interfaces et des adresses IP pour qu'elles correspondent à votre environnement. **Une balise `# *EDIT*` se trouve avant chaque option à éditer manuellement :**

* Interface côté LTSP : nom et gateway
* Interface côté réseau local : nom
* Seconde règle iptables : nom de l'interface côté LTSP
* Fichier de configuration du chroot : nom de l'utilisateur courant

Lancer le script `01.setup_server.sh`. Il installe les paquets principaux, configure les interfaces réseau, ajoute les règles iptables, génère le chroot, ajoute les groupes du système et génère le skeleton étudiant.

* Répondre `Yes` deux fois lors de la configuration de `iptables-persistent`

Attribuer un mot de passe au compte `ltsp_monitoring` qui va servir à l'enseignant à se connecter aux clients si l'authentifcation LDAP est mal configurée ou échoue.

```bash
$ sudo passwd ltsp_monitoring
```

#### Étape 2 : installation de Mitmproxy et Wireshark

Lancer le script `02.install_mitmproxy.sh`. Il télécharge les exécutables Mitmproxy.

Une fois l'exécution terminée, lancer l'exécutable `mitmproxy` pour générer ses certificats :

```bash
$ sudo /opt/mitmproxy/mitmproxy
```

Attention, les certificats seront créées pour l'utilisateur lançant la commande. Dans l'exemple ci-dessus, les certificats seront crées pour l'utilisateur root.

Arrêter la capture avec CTRL+C. Continuer l'installation en lançant le script `03.setup_mitmproxy`. Ce script configure Mitmproxy et installe Wireshark.

* Répondre `Yes` lorsque Wireshark demande si les non-superutilisateurs peuvent capturer des packets.

Lancer Wireshark, ouvrir le menu *Edit* > *Preferences* > *Protocols* > *TLS* puis ajouter le chemin `/opt/mitmproxy/sslkeylogfile.txt` dans le champs *(Pre)-Master-Secret log filename*.

Parler du script python

#### Étape 3 : installation du chroot

Lancer le script 04 avec la commande :

```bash
$ schroot -c focal -u root ./04.install_chroot.sh
```

Il entre dans le chroot, télécharge les paquets nécessaires au client, installe le certificat proxy et met en place les configurations de l'environnement.

* Garder l'encodage par défaut lors de l'upgrade des paquets
* Répondre `Yes` deux fois lors de la configuration de `iptables-persistent`
* Ne pas installer GRUB lors de l'installation de `ubuntu-desktop`

#### Étape 4 : installation de Logkeys dans le chroot

Lancer le script 05 avec la commande :

```bash
$ schroot -c focal -u root ./05.install_logkeys.sh
```

Il installe le keylogger Logkeys dans le chroot et le configure.

#### Étape 5 : installation du serveur, agent et frontend Zabbix

Lancer le script `06.install_zabbix`. Il installe les composants nécessaires à Zabbix sur le serveur, dont la base de données PostgreSQL et Apache.

* Un mot de passe pour la base de données est demandé pendant l'installation, le garder précieusement

Une fois l'exécution du script terminée, il ne reste que quelques étapes à effectuer :

1. Éditer le fichier `/etc/zabbix/zabbix_server.conf` et donner le mot de passe de la DB :

```
DBPassword=password
```

2. Éditer le fichier `/etc/zabbix/apache.conf` et décommenter les 2 `php_value date.timezone` en mettant `Europe/Zurich`:

```xml
<Directory "/usr/share/zabbix">
    ...

    <IfModule mod_php5.c>
        ...
        php_value date.timezone Europe/Zurich
    </IfModule>
    <IfModule mod_php7.c>
        ...
        php_value date.timezone Europe/Zurich
    </IfModule>
</Directory>
```

3. Exécuter les commandes suivantes :

```bash
$ sudo systemctl enable zabbix-server zabbix-agent apache2
$ sudo systemctl start zabbix-server zabbix-agent apache2
```

4. **Redémarrer le serveur** pour terminer l'installation de Zabbix

#### Étape 6 : installation de l'agent Zabbix dans le chroot

Lancer le script 07 avec la commande :

```bash
$ schroot -c focal -u root ./07.install_chroot_zabbix.sh
```

Il installe l'agent Zabbix dans le chroot et donne les permissions nécessaires à son fonctionnement.

Une fois l'exécution terminée, exécuter cette commande :

```bash
$ schroot -c focal -u root nano /etc/zabbix/zabbix_agentd.conf
```
Puis, modifier les valeurs des clés suivantes pour qu'elles soient exactement comme suit :

```bash
Server=192.168.67.1
ServerActive=192.168.67.1
#Hostname=Zabbix server
HostnameItem=system.hostname
```

#### Étape 7 : configurations manuelles

##### 7.1 Sur le serveur :

* Éditer le fichier `/etc/ltsp/ltsp.conf` et ajouter les lignes suivantes **sous les balises correspondantes** :

```bash
[server]
# Hide iPXE shell
POST_IPXE_HIDE_CONFIG="sed '/--key c/d' -i /srv/tftp/ltsp/ltsp.ipxe"
POST_IPXE_HIDE_SHELL="sed '/--key s/d' -i /srv/tftp/ltsp/ltsp.ipxe"
# Share home directory
NFS_HOME=1

[clients]
# Hide process information for other users
FSTAB_PROC="proc /proc proc defaults,hidepid=2 0 0"
# Share home directory with the clients
FSTAB_HOME="server:/home /home nfs defaults,nolock 0 0"

# Allow specific services
KEEP_SYSTEM_SERVICES="ssh"

# Copy the server SSH keys into clients. Required for SSH communication
POST_INIT_CP_KEYS="cp /etc/ltsp/ssh_host_* /etc/ssh/"

# Filter which users accounts are copied on the clients
PWMERGE_SUR="ltsp_monitoring"
```

* Éditer le fichier `/etc/gdm3/greeter.dconf-defaults` comme suit pour cacher la liste d'utilisateurs de la fenêtre de login :

```bash
# Décommenter les lignes suivantes
[org/gnome/login-screen]
disable-user-list=true
```

##### 7.2 Dans le chroot :

Entrer dans le schroot avec la commande :

```bash
$ schroot -c focal -u root
```

* Éditer le fichier `/etc/default/keyboard` comme suit pour paramétrer le clavier en français :

```bash
XKBLAYOUT="ch"
XKBVARIANT="fr"
```

* Éditer le fichier `/etc/gdm3/greeter.dconf-defaults` comme suit pour cacher la liste d'utilisateurs de la fenêtre de login :

```bash
# Décommenter les lignes suivantes
[org/gnome/login-screen]
disable-user-list=true
```

#### Étape 8 : installation de Veyon
De retour sur le serveur, vous pouvez lancer le script `08.install.veyon`. Il va installer et configurer l'utilitaire Veyon pour permettre de surveiller les écrans des élèves à distance. Vous pouvez faire le choix d'utiliser l'authentifcation par utilisateur + mot de passe ou par clé. Le choix par défaut est par identifiants mais cela peut être modifié en décommentant et commentant les parties indiquées dans le script.

Ensuite, une fois l'installation terminée le script python `veyon_zabbix.py` pourra être lancé une explicationn de son fonctionnement est dipsonible dans l'annexe `Annexe B - Utilisation Script Python`. Cependant, ce script nécessite que Zabbix soit configuré est puisse détecter des machines. Il faut donc avoir effectué l'étape 13 pour pouvoir lancer le dit script.

#### Étape 9 : installation de Veyon dans le chroot
Maintenant, veyon doit être installer sur les clients pour cela lancer la commande suivante :
```bash
$ schroot -c focal -u root ./09.install_chroot_veyon.sh
```
Comme pour l'étape précèdente, ce script va installer et configuer veyon. Vous pouvez également commenter ou décommenter certaines lignes selon la méthode d'authentification préférée.

#### Étape 10 : installation de PBIS-Open
Cette étape va permettre d'ajouter le serveur au domaine de la HEIG-VD pour permettre aux enseignants et assistants de se connecter avec leur compte. Pour réussir cela, le script `10.install_PBIS-Open` doit être lancé. Ce script va s'occuper d'installer et configurer l'application PBIS-Open. Pour cette étape, vous aurez besoin d'un compte ayant le droit d'ajouter une machine dans une unité organisationnelle dans l'AD. Pour cela, vous pouvez contacter le service informatique qui vous fournira le compte en question.

Vous pouvez rentrer les informations sur l'OU et le nom du compte dans le script aux emplacements marqués par XX. Un mot de passe sera donc demandé par le script pour vérifier l'authenticité du compte.

Il est fortement conseillé de redémarrer le serveur après l'installation. Néanmoins, cela n'est pas nécessaire pour faire fonctionner l'utilitaire.

#### Étape 11 : installation de PBIS-Open dans le chroot
Maintenant, comme pour veyon, PBIS-Open doit être installer sur les clients pour cela lancer la commande suivante :
```bash
$ schroot -c focal -u root ./11.install_chroot_PBIS-Open.sh
```
Ce script va installer et créer des scripts pour pouvoir ajouter et supprimer des clients du domaine. Pour plus d'explications sur l'utilité des ces scripts veuilliez vous reférrer au rapport final. Pour cette étape veuilliez contacter le service informatique pour qu'il vous fournisse un compte ayant le droit d'ajouter des machines à l'AD et remplacer les XX présent dans le fichier par les valeurs indiquées. Le mot de passe du compte sera nécessaire.

Une fois le script terminé, entrez dans le schroot avec la commande suivante :
```bash
$ schroot -c focal -u root
```

Une fois dans le schroot, faites les modfications suivantes dans le fichier `/lib/systemd/system/lwsmd.service` pour indiquer les scripts à exécuter au démarrage et à l'arrêt de l'application :
```bash
[Service]
Type=forking
ExecStart=/etc/ldap/connection.sh
ExecReload=/opt/pbis/bin/lwsm refresh
ExecStop=/etc/ldap/leave.sh
# We want systemd to give lwsmd some time to finish gracefully, but still want
# it to kill lwsmd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill lwsmd. We are sending useless SIGCONT here to give
# lwsmd time to finish.
KillSignal=SIGCONT
PrivateTmp=false
```

Puis, lancer une dernière commmande qui permettra de mettre en place une authentification correcte de pam avec le LDAP.

```bash
schroot -c focal -u root cp ./Templates_Secret/pam-files/* /etc/pam.d/
```

#### Étape 12 : création de l'image cliente LTSP

De retour sur le serveur, lancez le script `12.image.sh`. Il génère l'image, le menu iPXE et le fichier initrd, et partage le chroot en NFS.

#### Étape 13 : configuration de Zabbix Frontend & Server

Suivre la procédure `Annexe A - Importation configuration Zabbix.pdf` pour terminer l'installation de Zabbix sur le serveur. Une fois la configuration terminée vous pouvez lancer le script `veyon_zabbix.py` pour pouvoir surveiller les écrans des machines clientes. Une démonstration de son lancement est disponible dans l'annexe `Annexe B - Utilisation Script Python`.

#### Étape 14 : Installation et configuration de ElasticSearch

Pour installer la suite de logiciel permettant de capturer le traffic réseau il faut lancer le script `13.install_elasticsearch.sh`. Ce script va installer et configurer Elasticsearch et Logstash. Une fois le tout installer, il sera possible d'utiliser le script python `capture_trafic.py`. Ce script permet de démarrer une capture du traffic HTTP des étudiants pour pouvoir les afficher sur Grafana.

L'utilisation de ce script est démontré dans l'annexe `Annexe B - Utilisation Script Python.pdf`.

#### Étape 15 : Installation et configuration de Grafana

Dans un premier temps, lancez le script `14.install_grafana.sh`. Puis, suivez la procédure `Annexe C - Importation configuration Grafana.pdf` pour terminer l'installation de Grafana sur le serveur. Une fois la configuration terminée vous pouvez observer les différentes alertes et journaux pour surveiller les tests.


#### Étape 16 : tester l'environnement

Dès à présent, il devrait être possible de démarrer des clients LTSP.

Démarrer le proxy en naviguant dans `/opt/mitmproxy` et en lançant la commande. Ceci permettra aux clients d'avoir accès à Internet :

```bash
# Start capture
$ sudo ./mitmdump -s redirect_requests.py -w output
# Read capture
$ sudo ./mitmdump -s pretty_print.py -r output
```

Une fois un client démarré, son agent devrait s'inscrire tout seul dans les Hosts Zabbix et être monitoré. Une fois cela arrivé vous pouvez lancer le script `veyon_zabbix.py` pour avoir les clients sur Veyon également. Vous pourrez alors voir les écrans des élèves avec Veyon et les journaux sur Grafana grâce aux graphes.  

**Un compte `ltsp_monitoring` possédant les droits sudo existe expressément pour pouvoir se connecter aux clients et y effectuer des actions privilégiées.** N'hésitez pas à l'utiliser (avec ssh ou en se connectant directement sur le client).

### Configuration avec image

Si vous ne désirez effectuer toute la configuration précédente une image OVF vous est fournie. Mais, pour pouvoir la rendre fonctionnelles il faudra :
- Changer les interfaces dans les fichier yaml `/etc/netplan/02_config_ltsp.yaml` et `/etc/netplan/03_config_lan.yaml` en fonction des interfaces de votre machine. Pour voir les interfaces disponibles sur la machine vous pouvez lancer la commande `ip link show`.
- Si cela est bien configuré, après la commande `sudo netplan apply`, vous devriez voir les deux interfaces avec des addresse IP à l'aide de la commande `ifconfig`.
- Mettre à jour l'horloge grâce à la commande `timedatectl` pour pouvoir se synchroniser et se connecter à l'AD.
- Vous devrez également changer les configurations firewall du chroot et du serveur pour permettre la communication entre eux. Pour cela, allez dans le fichier `/etc/iptables/rules.v4`, du serveur et du client, et modifiez la deuxième règle pour avoir l'interface qui communiquera avec les clients.

Une fois ces changements effectués vous avez alors un serveur fonctionnel et vous pouvez y connecter des clients.

### Troubleshooting

Il est possible que certains problèmes apparaîssent malgré le suivi scrupuleux de la procédure :

* Si les clients ne parviennent pas à obtenir une adresse IP, voir si les règles IPtables sont OK. Il suffit qu'on ait oublié de modifier le nom de l'interface dans une règle pour que cela pose problème.
* Si les clients ne parviennent pas à se connecter au serveur TFTP, voir les logs de dnsmasq. Il suffit parfois de redémarrer le service.
* Si une interface semble DOWN, vérifier les configurations netplan et réappliquer si nécessaire.
* Si le serveur Zabbix apparaît "Down" dans la console, vérifier les logs dans `/var/log/zabbix/zabbix_agentd.log` et `/var/log/zabbix/zabbix_server.log`. Il peut arriver que le serveur communique avec son propre agent non pas avec l'adresse 127.0.0.1 mais avec l'adresse d'une autre interface. Si c'est le cas, il faut modifier les clés `Server` et `ServerActive` dans la configuration de l'agent pour les faire correspondre avec l'IP utilisée.
* Si l'agent Zabbix sur les clients ne démarre pas, vérifier le owner du dossier `/var/log/zabbix`. Il arrive que ce fichier change de propriétaire sans raison apparente. Cela devrait être `zabbix:zabbix`.
* Si les machines sur veyon indique que l'hôte n'est pas joignable vérifier qu'une instance veyon-server tourne sur le client.
* Si les client n'arrivent pas à se connecter à l'AD vérifié qu'il est possible de pinger einet.ad.eivd.ch.
