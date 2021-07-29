# SECRET II : Secure Environment for automatic test grading, part 2 - Installation

> Travail de Bachelor 2020-2021
>
> Auteur : Stéphane Teixeira Carvalho
>
> Basé sur le travail de : Caroline Monthoux
>
> Date : 30.07.2021



## Introduction

Ce document est une marche à suivre pour configurer l'environnement tel que mis en place dans le projet.

L'arborescence de dossiers est la suivante :

* `Installation/` contient tous les scripts d'installation et des annexes qui sont citées tout au long de ce document.
* `Python_Scripts/` contient des scripts Python permettant l'automatisation de certaines actions. Ceux-ci sont créés lors de l'installation, mais ils sont également disponibles dans ce dossier pour avoir un accès plus aisé au code.
* `Templates_Secret/` contient des fichiers servant de modèle pour les applications Zabbix, Grafana et pam.

**Ce document ainsi que les scripts qui l'accompagnent sont disponibles dans un dépôt GitHub. Vous pouvez y accéder à l'adresse https://github.com/Naludrag/SECRET-II-Installation.**

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

Éditer le fichier script `01.setup_server` pour remplacer les noms des interfaces et des adresses IP pour qu'elles correspondent à votre environnement. **Une balise `# *EDIT*` se trouve avant chaque option à modifier manuellement :**

* Interface côté LTSP : nom et gateway
* Interface côté réseau local : nom
* Seconde règle iptables : nom de l'interface côté LTSP
* Fichier de configuration du chroot : nom de l'utilisateur courant

Lancer le script `01.setup_server.sh`. Il installe les paquets principaux, configure les interfaces réseau, ajoute les règles iptables, génère le chroot, ajoute les groupes du système et génère le skeleton étudiant.

* Répondre `Yes` deux fois lors de la configuration de `iptables-persistent`

Attribuer un mot de passe au compte `ltsp_monitoring` qui va servir à l'enseignant à se connecter aux clients si l'authentification LDAP n'est pas configurée ou échoue.

```bash
$ sudo passwd ltsp_monitoring
```

#### Étape 2 : installation de Mitmproxy et Wireshark

Lancer le script `02.install_mitmproxy.sh`. Il télécharge les exécutables Mitmproxy.

Une fois l'exécution terminée, lancer l'exécutable `mitmproxy` pour générer ses certificats :

```bash
$ sudo /opt/mitmproxy/mitmproxy
```

Attention, les certificats seront créés pour l'utilisateur lançant mitmproxy. Dans l'exemple ci-dessus, ils seront générés pour l'utilisateur **root**. Dès lors, le script `03.setup_mitmproxy` devra être lancé avec le mot-clé sudo afin que les certificats s'installent correctement `sudo ./03.setup_mitmproxy`.

Arrêter la capture avec CTRL+C. Continuer l'installation en lançant le script `03.setup_mitmproxy`. Ce script configure Mitmproxy et installe Wireshark.

* Répondre `Yes` lorsque Wireshark demande si les non-superutilisateurs peuvent capturer des packets.

Lancer Wireshark, ouvrir le menu *Edit* > *Preferences* > *Protocols* > *TLS* puis ajouter le chemin `/opt/mitmproxy/sslkeylogfile.txt` dans le champs *(Pre)-Master-Secret log filename*.

Après l'installation de ce script, le fichier `mitmproxy_configfile_start.py` sera créé dans le dossier `/usr/local/bin`. Ce script Python va permettre de démarrer Mitmproxy avec un fichier de configuration pour bloquer des sites web. Une explication sur son fonctionnement est fournie dans l'annexe `Annexe B - Utilisation Script Python.pdf`.

#### Étape 3 : installation du chroot

Lancer le script 04 avec la commande :

```bash
$ schroot -c focal -u root ./04.install_chroot.sh
```

Il entre dans le chroot, télécharge les paquets nécessaires au client, installe le certificat proxy et met en place les configurations de l'environnement.

* Garder l'encodage par défaut lors de l'upgrade des paquets
* Répondre `Yes` deux fois lors de la configuration de `iptables-persistent`
* Ne pas installer GRUB lors de l'installation de `ubuntu-desktop`

#### Étape 4 : installation du serveur, agent et frontend Zabbix

Lancer le script `05.install_zabbix`. Il installe les composants nécessaires à Zabbix sur le serveur, dont la base de données PostgreSQL et Apache.

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

#### Étape 5 : installation de l'agent Zabbix dans le chroot

Lancer le script 06 avec la commande :

```bash
$ schroot -c focal -u root ./06.install_chroot_zabbix.sh
```

Il installe l'agent Zabbix dans le chroot et donne les permissions nécessaires à son fonctionnement.

Une fois l'exécution terminée, lancer cette commande :

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

#### Étape 6 : configurations manuelles

##### 6.1 Sur le serveur :

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

##### 6.2 Dans le chroot :

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

#### Étape 7 : installation de Veyon
De retour sur le serveur, vous pouvez lancer le script `07.install.veyon`. Il va installer et configurer l'utilitaire Veyon pour surveiller les écrans des élèves à distance. Vous pouvez faire le choix de mettre en place une authentification par utilisateur + mot de passe ou par clé. Celui par défaut est par identifiants, mais cela peut être modifié en décommentant et commentant les parties indiquées dans le script.

Ensuite, une fois l'installation terminée, le script Python `discover_clients_veyon.py` pourra être lancé. Une explication de son fonctionnement est disponible dans l'annexe `Annexe B - Utilisation Script Python`. Cependant, il nécessite que Zabbix soit configuré et puisse détecter des machines. Il faut donc avoir effectué l'étape 12 pour pouvoir exécuter ledit script.

#### Étape 8 : installation de Veyon dans le chroot
Maintenant, Veyon doit être installé sur les clients. Pour cela, lancer la commande suivante :
```bash
$ schroot -c focal -u root ./08.install_chroot_veyon.sh
```
Comme pour l'étape précédente, ce script va installer et configurer Veyon. Vous pouvez également commenter ou décommenter certaines lignes selon la méthode d'authentification préférée.

#### Étape 9 : installation de PBIS-Open
Cette étape va connecter le serveur au domaine de la HEIG-VD pour permettre aux enseignants et assistants d'utiliser leur compte personnel. Pour réussir cela, le script `09.install_PBIS-Open` doit être lancé. Il va s'occuper d'installer et configurer l'application PBIS-Open. Pour mener à bien son exécution, vous aurez besoin d'un compte ayant le droit d'ajouter une machine dans une unité organisationnelle de l'AD. Celui par défaut, qui a été utilisé pendant le développement, est **tbaddvm**. Cependant, il est possible que celui-ci soit désactivé et le script échouera dans ce cas. Pour résoudre cela, vous pouvez contacter le service informatique afin qu'il vous fournisse soit un nouveau compte pour ajouter des machines soit vous procurez les droits pour le faire vous-même.

Une fois l'installation terminée **redémarrer** le serveur.

#### Étape 10 : installation de PBIS-Open dans le chroot
Maintenant, comme pour Veyon, PBIS-Open doit être installé sur les clients pour cela lancez la commande suivante :
```bash
$ schroot -c focal -u root ./10.install_chroot_PBIS-Open.sh
```
Ce script va installer et créer d'autres scripts pour pouvoir ajouter et supprimer des ordinateurs au domaine. Pour plus d'explications sur leur utilité, veuilliez vous référer au rapport final. Pour cette partie, il faudra modifier certaines lignes du fichier si le compte de l'étape précédente n'était pas **tbaddvm**. Les endroits, dans lesquels une modification est à effectuer, sont marqués par le mot-clé `# *EDIT*`.

Une fois le script terminé, entrez dans le schroot avec la commande suivante :
```bash
$ schroot -c focal -u root nano /lib/systemd/system/lwsmd.service
```

Et effectuer les modifications suivantes, dans le fichier `/lib/systemd/system/lwsmd.service`, pour indiquer les scripts à exécuter au démarrage et à l'arrêt de l'application :
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

Puis, lancer une commande qui permettra de mettre en place une authentification correcte de pam avec le LDAP.

```bash
schroot -c focal -u root cp ../../Templates_Secret/pam-files/* /etc/pam.d/
```

Finalement, lancer la commande suivante :
```bash
schroot -c focal -u root pam-auth-update
```
Répondez de manière négative **No** au message qui sera affiché. Cela permettra d'empêcher les clients de pouvoir réécrire la configuration pam et ainsi garder celle copiée.

#### Étape 11 : création de l'image cliente LTSP

De retour sur le serveur, lancez le script `11.image.sh`. Il génère l'image, le menu iPXE et le fichier initrd, et partage le chroot en NFS.

#### Étape 12 : configuration de Zabbix Frontend & Server

Suivre la procédure `Annexe A - Importation configuration Zabbix.pdf` pour terminer l'installation de Zabbix sur le serveur. Une fois la configuration achevée, vous pouvez exécuter le script `discover_clients_veyon.py` afin de surveiller les écrans des machines clientes. Une explication et démonstration de son lancement est disponible dans l'annexe `Annexe B - Utilisation Script Python`.

#### Étape 13 : installation et configuration de Elasticsearch

Pour installer la suite de logiciels afin de capturer le trafic réseau, il faut lancer le script `12.install_elasticsearch.sh`. Il va télécharger et configurer Elasticsearch et Logstash.

Ensuite, par défaut, Elasticsearch va consommer toute la RAM disponible sur la machine ce qui va faire échouer le service. Pour modifier cela, faites les changements suivants dans le fichier `/etc/elasticsearch/jvm.options`. Cela va indiquer à Elasticsearch de n'utiliser au maximum que 1GB de RAM.

```bash
...
################################################################
## IMPORTANT: JVM heap size
################################################################
...
-Xms1g
-Xmx1g
...
```

Une fois le tout mis en place, il sera possible d'utiliser le script python `capture_trafic.py`. Il permet d'automatiser le lancement d'une capture. L'utilisation de celui-ci est démontrée dans l'annexe `Annexe B - Utilisation Script Python.pdf`.

#### Étape 14 : installation et configuration de Grafana

Dans un premier temps, lancer le script `13.install_grafana.sh` qui va permettre d'installer et configurer Grafana ainsi que de mettre en place le site web. Puis, suivez la procédure `Annexe C - Importation configuration Grafana.pdf` pour terminer l'installation de Grafana sur le serveur. Une fois la configuration terminée vous pouvez observer les différents alertes et journaux pour surveiller les tests.

Les fichiers sources du site web sont disponibles dans un dépôt Github https://github.com/Naludrag/SECRET-II-Site.

#### Étape 15 : mise en place du dossier tests

Pour terminer l'installation, lancer le dernier script se nommant `14.install_tests_script.sh`. Il s'occupera de créer et installer les scripts pour mettre en place le dossier `tests` des élèves permettant le partage et téléchargement de fichier.

```bash
schroot -c focal -u root ./15.install_tests_script.sh
```


#### Étape 16 : tester l'environnement

Dès à présent, il devrait être possible de démarrer des clients LTSP.

Créer, ensuite, un fichier de configuration en allant sur la page web http://localhost/block_sites.php. Une fois celui-ci généré, lancez le script `mitmproxy_configfile_start.py`. Cela démarrera le proxy et permettra aux clients d'avoir accès à Internet :

```bash
$ python3 /usr/local/bin/mitmproxy_configfile_start.py
```

Une fois celui-ci exécuté, le script `capture_trafic.py` pourra être démarré pour avoir un suivi du trafic réseau. Une attention particulière doit être apportée à l'interface indiquée dans le script, car si celle-ci est erronée, la capture ne fonctionnera pas correctement.
```bash
$ sudo python3 /usr/local/bin/capture_trafic.py
```

Une fois un client démarré, son agent devrait s'inscrire tout seul dans les Hosts Zabbix et être monitoré. Dès lors, vous pouvez lancer le script `discover_clients_veyon.py` pour avoir les clients sur Veyon également. Vous pourrez alors voir les écrans des élèves avec Veyon et les journaux sur Grafana grâce aux graphes.

Un site web devrait être disponible en allant à l'adresse http://localhost/. Depuis celui-ci, vous pouvez envoyer ou télécharger des fichiers aux étudiants.
Pour plus d'information sur celui-ci, veuilliez vous référer au dépôt https://github.com/Naludrag/SECRET-II-Site.

**Un compte `ltsp_monitoring` possédant les droits sudo existe expressément pour pouvoir se connecter aux clients et y effectuer des actions privilégiées.** N'hésitez pas à l'utiliser (avec ssh ou en se connectant directement sur le client).

### Configuration avec image

Si vous ne désirez effectuer toute la configuration précédente, une image OVF vous est fournie. Elle est téléchargeable avec le lien suivant https://drive.switch.ch/index.php/s/RGG4zw5Tp0udirB


Toutefois, pour pouvoir la rendre fonctionnelle, il faudra :
- Selectionner les bons adapteurs réseaux pour la machine. Un donnant sur le LAN et un autre sur le réseau des clients.
- Changer les interfaces dans les fichiers yaml `/etc/netplan/02_config_ltsp.yaml` et `/etc/netplan/03_config_lan.yaml` en fonction de celles présentes sur la machine. Pour voir celles disponibles, vous pouvez lancer la commande `ip link show`.
- Si cela est bien configuré, après l'exécution de `sudo netplan apply`, vous devriez voir les deux interfaces accompagnées des adresses IP à l'aide de `ifconfig`.
- Mettre à jour l'horloge grâce à la commande `timedatectl` pour pouvoir se synchroniser et se connecter à l'AD.
- Vous devrez également modifier le pare-feu de l'environnement chroot et du serveur pour permettre la communication entre ceux-ci. Pour cela, allez dans le fichier `/etc/iptables/rules.v4` de chacun et changez la deuxième règle pour avoir l'interface qui sera du côtée avec les clients.
- Finalement, redémarrez le serveur pour qu'il prenne en compte les changements.

Une fois ces étapes effectuées, vous avez alors un serveur fonctionnel et vous pouvez y ajouter des clients. Vous pourrez vous connecter avec votre compte HEIG-VD ou avec les comptes locaux : **adminsecret** avec le mot de passe **admin** ou **ltsp_monitoring** avec le mot de passe **admin** également.

Si vous désirez changer leur mot de passe veuilliez entrer la commande suivante :
```bash
$ sudo passwd compte
```

### Troubleshooting

Il est possible que certains problèmes apparaissent malgré le suivi scrupuleux de la procédure :

* Si les clients ne parviennent pas à obtenir une adresse IP, voir si les règles IPtables sont OK. Il suffit qu'on ait oublié de modifier le nom de l'interface dans une règle pour que cela pose problème.
* Si les clients ne parviennent pas à se connecter au serveur TFTP, voir les logs de dnsmasq. Il suffit parfois de redémarrer le service.
* Si une interface semble DOWN, vérifier les configurations netplan et réappliquer si nécessaire.
* Si le serveur Zabbix apparaît "Down" dans la console, vérifier les logs dans `/var/log/zabbix/zabbix_agentd.log` et `/var/log/zabbix/zabbix_server.log`. Il peut arriver que le serveur communique avec son propre agent non pas avec l'adresse 127.0.0.1 mais avec l'adresse d'une autre interface. Si c'est le cas, il faut modifier les clés `Server` et `ServerActive` dans la configuration de l'agent pour les faire correspondre avec l'IP utilisée.
* Si l'agent Zabbix sur les clients ne démarre pas, vérifier le owner du dossier `/var/log/zabbix`. Il arrive que ce fichier change de propriétaire sans raison apparente. Cela devrait être `zabbix:zabbix`.
* Lors de l'initialisation de Zabbix, il est possible qu'une erreur intervienne lors de la dernière étape de configuration. Pour résoudre cela, suivez simplement les indications données et le message devrait disparaître.
* Si les machines sur Veyon indiquent que l'hôte n'est pas joignable, vérifier qu'une instance veyon-server tourne sur le client.
* Si une boucle de login apparaît chez les clients vérifier que le serveur est joint à l'AD.
* Si le téléchargement de fichier ou envoi échoue pour un étudiant en particulier, vérifiez les droits de www-data sur le dossier tests de celui-ci.
